import AVFoundation
import SwiftUI

/// A simple manager for text-to-speech using AVSpeechSynthesizer.
/// This uses the built-in iOS voices without requiring any downloads.
@MainActor
class TextToSpeechManager: ObservableObject {
    @Published var isSpeaking: Bool = false
    @Published var isPlayingMeditation: Bool = false
    @Published var audioBalance: Double = 1.0  // 0.0 (0% ambient) to 1.0 (100% ambient)

    // Closed captioning support
    @Published var currentPhrase: String = ""
    @Published var previousPhrase: String = ""

    
    let synthesizer = AVSpeechSynthesizer()  // Internal access for pause/resume from VoiceSettingsView
    private let speechDelegate: SpeechDelegate
    private var repeatCount = 0
    private let maxRepeats = 10
    private var isCustomMode: Bool = false
    private var queuedUtteranceCount: Int = 0
    private var sessionId: UUID = UUID()  // Track current meditation session
    private static let meditationSpeechRate: Float = 1.0  // Calm, slow rate for meditation
    private static let meditationPitchMultiplier: Float = 1.0  // Slightly lower pitch for calmer

    // Wake-up greeting phrases (randomly selected when alarm triggers after meditation completion)
    private static let wakeUpGreetings: [String] = [
        "Welcome back",
        "Greetings",
        "Here we are",
        "Returning to awareness",
        "Welcome back to this space"
    ]

    // Track phrases for closed captioning
    private var allPhrases: [String] = []
    private var currentPhraseIndex: Int = 0

    // Reference to custom meditation manager for random selection
    weak var customMeditationManager: CustomMeditationManager?

    // Callback to notify when ambient volume changes
    var onAmbientVolumeChanged: ((Float) -> Void)? = nil

    let voiceVolume: Float = 0.25

    // Track last played meditation to avoid consecutive repeats
    private var lastPlayedMeditationText: String? = nil
    
    var ambientVolume: Float {
        // Balance ranges from 0.0 (0% ambient) to 1.0 (100% ambient)
        // At 0.0: ambient = 0.0
        // At 1.0: ambient = 0.6 (max ambient volume)
        return Float(audioBalance * 0.6)
    }
    
    init() {
        let delegate = SpeechDelegate()
        speechDelegate = delegate
        synthesizer.delegate = speechDelegate
        delegate.manager = self
    }
    
    /// Call this whenever the balance changes to notify the callback
    func updateVolumesFromBalance() {
        onAmbientVolumeChanged?(ambientVolume)
    }
    
    /// Starts speaking the test phrase, repeating 10 times
    func startSpeaking() {
        guard !isSpeaking else { return }
        
        isSpeaking = true
        isCustomMode = false
        repeatCount = 0
        speakNextPhrase()
    }
    
    /// Starts speaking custom text (only once, no repeating)
    func startSpeakingCustomText(_ text: String) {
        guard !isSpeaking else { return }
        guard !text.isEmpty else { return }
        
        isSpeaking = true
        isCustomMode = true
        
        let utterance = AVSpeechUtterance(string: text)
        let voice = VoiceManager.shared.getPreferredVoice()
        let speechRateMultiplier = VoiceManager.shared.getSpeechRateMultiplier(for: voice)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * speechRateMultiplier
        utterance.pitchMultiplier = Self.meditationPitchMultiplier
        utterance.volume = voiceVolume
        utterance.voice = voice

        synthesizer.speak(utterance)
    }
    
    func getRandomMeditation() -> String? {
        // Build pool of all available meditations (presets + customs)
        var allMeditations: [(text: String, source: String)] = []

        // Add all preset meditation files (check up to 100 to future-proof)
        for i in 1...100 {
            if let url = Bundle.main.url(forResource: "preset_meditation\(i)", withExtension: "txt"),
               let text = try? String(contentsOf: url, encoding: .utf8) {
                allMeditations.append((text.trimmingCharacters(in: .whitespacesAndNewlines), "preset \(i)"))
            }
        }

        // Add all custom meditations
        if let customManager = customMeditationManager {
            for meditation in customManager.meditations {
                allMeditations.append((meditation.text, "custom: \(meditation.title)"))
            }
        }

        guard !allMeditations.isEmpty else {
            return nil
        }

        // Filter out the last played meditation if we have more than one option
        if let lastPlayed = lastPlayedMeditationText, allMeditations.count > 1 {
            allMeditations = allMeditations.filter { $0.text != lastPlayed }
        }

        // Randomly select one meditation from the filtered pool
        let selected = allMeditations.randomElement()!

        // Store this meditation as the last played
        lastPlayedMeditationText = selected.text

        return selected.text
    }
    
    /// Starts speaking a random meditation from text files
    func startSpeakingRandomMeditation() {
        guard !isSpeaking else { return }
        
        // Try to load a random meditation file
        guard let meditationText = loadRandomMeditationFile() else {
            return
        }
        
        isSpeaking = true
        isCustomMode = true  // Treat like custom - play once, don't repeat
        
        let utterance = AVSpeechUtterance(string: meditationText)
        let voice = VoiceManager.shared.getPreferredVoice()
        let speechRateMultiplier = VoiceManager.shared.getSpeechRateMultiplier(for: voice)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * speechRateMultiplier
        utterance.pitchMultiplier = Self.meditationPitchMultiplier
        utterance.volume = voiceVolume
        utterance.voice = voice

        synthesizer.speak(utterance)
    }
    
    /// Automatically adds pauses to text: 2s after sentences, 4s after paragraphs
    private func addAutomaticPauses(to text: String) -> String {
        var result = ""
        let paragraphs = text.components(separatedBy: .newlines)
        
        for (index, paragraph) in paragraphs.enumerated() {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines
            guard !trimmed.isEmpty else {
                result += "\n"
                continue
            }
            
            // Split into sentences (roughly)
            let sentences = trimmed.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            
            for sentence in sentences {
                let trimmedSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedSentence.isEmpty else { continue }
                
                // Check if this sentence already has a pause marker
                if trimmedSentence.range(of: #"\(\d+(?:\.\d+)?s\)\s*$"#, options: .regularExpression) == nil {
                    // No pause found, add automatic 2s pause
                    result += trimmedSentence + " (2s)\n"
                } else {
                    // Already has a pause, keep it
                    result += trimmedSentence + "\n"
                }
            }
            
            // Add longer pause between paragraphs (except after the last one)
            if index < paragraphs.count - 1 {
                result += "(4s)\n"
            }
        }
        
        return result
    }
    
    /// Starts speaking text with embedded pauses like "(4s)" – splits into utterances automatically
    func startSpeakingWithPauses(_ text: String) {
        guard !text.isEmpty else {
            return
        }

        // Stop any currently playing meditation
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // Create new session ID to invalidate any pending callbacks from old session
        sessionId = UUID()

        // Reset ALL state immediately
        isSpeaking = false
        isPlayingMeditation = false
        isCustomMode = false
        queuedUtteranceCount = 0
        repeatCount = 0
        currentPhrase = ""
        previousPhrase = ""
        allPhrases = []
        currentPhraseIndex = 0

        // Clear any previous meditation completion flag
        UserDefaults.standard.removeObject(forKey: "meditationCompletedSuccessfully")

        // Remove question marks to prevent voice inflection changes
        let textWithoutQuestions = text.replacingOccurrences(of: "?", with: "")

        // Check if text has any pause markers
        let hasPauseMarkers = textWithoutQuestions.range(of: #"\(\d+(?:\.\d+)?[sm]\)"#, options: .regularExpression) != nil

        // If no pause markers found, add automatic ones
        let processedText = hasPauseMarkers ? textWithoutQuestions : addAutomaticPauses(to: textWithoutQuestions)

        // Split by both newlines and pause markers
        let phrases = extractPhrasesWithPauses(from: processedText)

        // Filter out empty phrases first
        let validPhrases = phrases.filter { !$0.phrase.isEmpty }

        // Clean all phrases and filter again (safety check for pause markers)
        let cleanedPhrases: [(phrase: String, delay: TimeInterval)] = validPhrases.compactMap { (phrase, delay) in
            // CRITICAL SAFETY CHECK: Remove any pause markers that might have slipped through
            // This prevents iOS from speaking pause markers like "(14s)" as "pause equals fourteen thousand"
            let cleanPhrase = phrase.replacingOccurrences(
                of: #"\(\d+(?:\.\d+)?[sm]\)"#,
                with: "",
                options: .regularExpression
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            return cleanPhrase.isEmpty ? nil : (cleanPhrase, delay)
        }

        // ULTRA-CLEAN all phrases one more time before using them
        let ultraCleanedPhrases: [(phrase: String, delay: TimeInterval)] = cleanedPhrases.compactMap { (phrase, delay) in
            // ULTRA-PARANOID SAFETY CHECK: Strip ALL parenthetical content
            var ultraCleanPhrase = phrase

            // First try the specific regex
            ultraCleanPhrase = ultraCleanPhrase.replacingOccurrences(
                of: #"\(\d+(?:\.\d+)?[sm]\)"#,
                with: "",
                options: .regularExpression
            )

            // Nuclear option: remove ANY content in parentheses that looks like a pause
            ultraCleanPhrase = ultraCleanPhrase.replacingOccurrences(
                of: #"\([0-9][^)]*\)"#,
                with: "",
                options: .regularExpression
            )

            ultraCleanPhrase = ultraCleanPhrase.trimmingCharacters(in: .whitespacesAndNewlines)

            return ultraCleanPhrase.isEmpty ? nil : (ultraCleanPhrase, delay)
        }

        // CRITICAL BUG FIX: Validate that we have content to speak before setting state
        // If text processing resulted in no speakable content, don't show meditation as playing
        guard !ultraCleanedPhrases.isEmpty else {
            // No valid phrases to speak - reset state and return early
            isSpeaking = false
            isPlayingMeditation = false
            isCustomMode = false
            queuedUtteranceCount = 0
            currentPhrase = ""
            previousPhrase = ""
            allPhrases = []
            currentPhraseIndex = 0
            return
        }

        // Store ULTRA-cleaned phrases for closed captioning (so VoiceOver doesn't read pause markers)
        allPhrases = ultraCleanedPhrases.map { $0.phrase }

        // Calculate total utterance count (speech + silent pause utterances)
        var totalUtteranceCount = 0
        for (_, delay) in ultraCleanedPhrases {
            totalUtteranceCount += 1  // Count the speech utterance

            // Count silent pause utterances
            if delay > 0 {
                let numPauses = Int(ceil(delay / 5.0))  // Break into 5-second chunks
                totalUtteranceCount += numPauses
            }
        }

        // Set the count of ALL utterances we're about to queue (speech + silent)
        queuedUtteranceCount = totalUtteranceCount

        // NOW set speaking state (after count is set)
        isSpeaking = true
        isPlayingMeditation = true
        isCustomMode = true

        // Capture the current session ID to attach to all utterances
        let currentSessionId = sessionId

        // CRITICAL: Get the voice ONCE before the loop to ensure all utterances use the same voice
        // If we call getPreferredVoice() inside the loop, it will return a different random voice
        // for each utterance when no voice preference is saved
        let voice = VoiceManager.shared.getPreferredVoice()
        let speechRateMultiplier = VoiceManager.shared.getSpeechRateMultiplier(for: voice)

        // Auto-save the voice preference for first-time users
        // This ensures the same random voice is used across all meditation sessions
        // until the user explicitly selects a different voice in Voice Settings
        if VoiceManager.shared.preferredVoiceIdentifier == nil {
            VoiceManager.shared.preferredVoiceIdentifier = voice?.identifier
        }

        for (ultraCleanPhrase, delay) in ultraCleanedPhrases {
            let utterance = AVSpeechUtterance(string: ultraCleanPhrase)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * speechRateMultiplier
            utterance.pitchMultiplier = Self.meditationPitchMultiplier
            utterance.volume = voiceVolume
            utterance.voice = voice

            // Tag this utterance with the session ID so we can validate callbacks
            speechDelegate.tagUtterance(utterance, withSessionId: currentSessionId)

            synthesizer.speak(utterance)

            // For pauses, queue multiple silent utterances to create the pause
            // This avoids the bug where postUtteranceDelay causes iOS to speak the delay value
            if delay > 0 {
                let numPauses = Int(ceil(delay / 5.0))  // Break into 5-second chunks
                let pausePerChunk = delay / Double(numPauses)

                for _ in 0..<numPauses {
                    let silentUtterance = AVSpeechUtterance(string: "")  // Empty string for silence
                    silentUtterance.rate = AVSpeechUtteranceDefaultSpeechRate
                    silentUtterance.volume = 0.0  // Silent
                    silentUtterance.postUtteranceDelay = pausePerChunk
                    silentUtterance.voice = AVSpeechSynthesisVoice(language: "en-US")

                    // Tag silent utterances with session ID too
                    speechDelegate.tagUtterance(silentUtterance, withSessionId: currentSessionId)

                    synthesizer.speak(silentUtterance)
                }
            }
        }
    }

    /// Extracts phrases and their associated pauses from text
    private func extractPhrasesWithPauses(from text: String) -> [(phrase: String, delay: TimeInterval)] {
        var result: [(String, TimeInterval)] = []

        // Pattern to match pause markers anywhere in text: (3s), (2.5s), (1m), (1.5m), etc.
        let pattern = #"\((\d+(?:\.\d+)?)(s|m)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            // If regex fails, return the whole text with no delay
            return [(text.trimmingCharacters(in: .whitespacesAndNewlines), 0.0)]
        }

        // First, let's extract all matches and their delays
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

        // If no matches, return the whole text
        guard !matches.isEmpty else {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return [(trimmed, 0.0)]
            }
            return []
        }

        var lastIndex = text.startIndex

        for match in matches {
            guard let matchRange = Range(match.range, in: text) else { continue }

            // Get the phrase before this pause marker
            let phraseBeforePause = String(text[lastIndex..<matchRange.lowerBound])

            // Get the pause duration and unit
            guard let durationRange = Range(match.range(at: 1), in: text),
                  let unitRange = Range(match.range(at: 2), in: text),
                  let value = Double(text[durationRange]) else {
                continue
            }

            let unit = String(text[unitRange])

            // Convert to seconds
            let seconds: TimeInterval = {
                switch unit {
                case "m":
                    return value * 60.0  // Convert minutes to seconds
                case "s":
                    return value
                default:
                    return value  // Default to seconds
                }
            }()

            let trimmedPhrase = phraseBeforePause.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedPhrase.isEmpty {
                result.append((trimmedPhrase, seconds))
            }

            // Move past this pause marker
            lastIndex = matchRange.upperBound
        }

        // Add any remaining text after the last pause marker (with no delay)
        let remainingText = String(text[lastIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)

        // CRITICAL: Remove any pause markers from remaining text as a safety check
        // This ensures no pause markers accidentally get spoken
        let cleanedRemainingText = remainingText.replacingOccurrences(
            of: #"\(\d+(?:\.\d+)?[sm]\)"#,
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleanedRemainingText.isEmpty {
            result.append((cleanedRemainingText, 0.0))
        }

        return result
    }
        
    /// Loads a random meditation text file from the bundle (checks up to 100 preset files)
    private func loadRandomMeditationFile() -> String? {
        // Load all available preset meditation files (check up to 100 to future-proof)
        var validURLs: [URL] = []

        for i in 1...100 {
            if let url = Bundle.main.url(forResource: "preset_meditation\(i)", withExtension: "txt") {
                validURLs.append(url)
            }
        }
        
        guard !validURLs.isEmpty else {
            return nil
        }

        // Pick a random preset meditation file
        let randomURL = validURLs.randomElement()!

        // Load the text
        guard let text = try? String(contentsOf: randomURL, encoding: .utf8) else {
            return nil
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Speaks a random wake-up greeting (used when alarm triggers after meditation completion)
    func speakWakeUpGreeting() {
        guard let greeting = Self.wakeUpGreetings.randomElement() else { return }

        let utterance = AVSpeechUtterance(string: greeting)
        let voice = VoiceManager.shared.getPreferredVoice()
        let speechRateMultiplier = VoiceManager.shared.getSpeechRateMultiplier(for: voice)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * speechRateMultiplier
        utterance.pitchMultiplier = Self.meditationPitchMultiplier
        utterance.volume = voiceVolume
        utterance.voice = voice

        synthesizer.speak(utterance)
    }

    /// Stops speaking immediately
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)

        // CRITICAL: Invalidate the session ID to reject any pending callbacks
        sessionId = UUID()

        isSpeaking = false
        isPlayingMeditation = false
        repeatCount = 0
        queuedUtteranceCount = 0
        currentPhrase = ""
        previousPhrase = ""

        // Clear meditation completion flag since it was stopped manually
        UserDefaults.standard.removeObject(forKey: "meditationCompletedSuccessfully")
    }
    
    private func speakNextPhrase() {
        guard isSpeaking && repeatCount < maxRepeats else {
            isSpeaking = false
            return
        }
        
        let utterance = AVSpeechUtterance(string: "All work and no play makes Jack a dull boy.")
        
        // Configure the voice - using the default system voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Self.meditationSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = voiceVolume
        utterance.pitchMultiplier = Self.meditationPitchMultiplier
        
        // Use default US English voice
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        
        synthesizer.speak(utterance)
        repeatCount += 1
    }
    
    // Called by the delegate when an utterance starts
    fileprivate func didStartUtterance(_ utterance: AVSpeechUtterance) {
        // Only update closed captioning for actual speech (not silent utterances)
        // Silent utterances have empty strings
        guard !utterance.speechString.isEmpty else {
            return
        }

        // Update closed captioning when a phrase starts speaking
        if currentPhraseIndex < allPhrases.count {
            let newPhrase = allPhrases[currentPhraseIndex]
            previousPhrase = currentPhrase
            currentPhrase = newPhrase
        }
    }

    // Called by the delegate when speech finishes
    fileprivate func didFinishSpeaking(_ utterance: AVSpeechUtterance, sessionId: UUID) {
        // Ignore callbacks from old sessions
        guard sessionId == self.sessionId else {
            return
        }

        // Ignore callbacks if we're not actually supposed to be speaking
        guard isSpeaking else {
            return
        }

        // If custom mode (meditation), update closed captioning and track utterance completion
        if isCustomMode {
            // Only increment phrase index for actual speech (not silent utterances)
            if !utterance.speechString.isEmpty {
                currentPhraseIndex += 1  // Move to next phrase for closed captioning
            }

            // Decrement the queued utterance count (this counts both speech AND silent utterances)
            queuedUtteranceCount -= 1

            // Only stop when all utterances are done
            if queuedUtteranceCount <= 0 {
                isSpeaking = false
                // Keep isPlayingMeditation = true so the leaf stays green after completion
                // This allows user to see that meditation completed successfully
                // User can manually toggle leaf off if desired
                isCustomMode = false
                queuedUtteranceCount = 0
                currentPhrase = ""
                previousPhrase = ""

                // Mark that a meditation completed successfully (for wake-up greeting feature)
                UserDefaults.standard.set(true, forKey: "meditationCompletedSuccessfully")
            }
            return
        }

        if repeatCount < maxRepeats {
            // Small pause between repetitions
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.speakNextPhrase()
            }
        } else {
            isSpeaking = false
        }
    }
}

// Delegate to handle speech events
private class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    weak var manager: TextToSpeechManager?

    // Dictionary to track which session each utterance belongs to
    private var utteranceSessionIds: [ObjectIdentifier: UUID] = [:]
    private let lock = NSLock()

    override init() {
        super.init()
    }

    /// Tag an utterance with a session ID before speaking it
    func tagUtterance(_ utterance: AVSpeechUtterance, withSessionId sessionId: UUID) {
        lock.lock()
        defer { lock.unlock() }
        utteranceSessionIds[ObjectIdentifier(utterance)] = sessionId
    }

    /// Get the session ID for an utterance, if it was tagged
    private func getSessionId(for utterance: AVSpeechUtterance) -> UUID? {
        lock.lock()
        defer { lock.unlock() }
        let id = utteranceSessionIds[ObjectIdentifier(utterance)]
        return id
    }

    /// Remove the session ID tracking for an utterance (cleanup)
    private func removeSessionId(for utterance: AVSpeechUtterance) {
        lock.lock()
        defer { lock.unlock() }
        utteranceSessionIds.removeValue(forKey: ObjectIdentifier(utterance))
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            manager?.didStartUtterance(utterance)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Get the session ID for this utterance (or use a nil UUID if untagged)
        let sessionId = getSessionId(for: utterance) ?? UUID()

        // Clean up the tracking
        removeSessionId(for: utterance)

        Task { @MainActor in
            manager?.didFinishSpeaking(utterance, sessionId: sessionId)
        }
    }
}
