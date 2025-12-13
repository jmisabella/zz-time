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

    private static let meditationSpeechRate: Float = 0.55  // Calm, slow rate for meditation
    private let synthesizer = AVSpeechSynthesizer()
    private let speechDelegate: SpeechDelegate
    private var repeatCount = 0
    private let maxRepeats = 10
    private var isCustomMode: Bool = false
    private var queuedUtteranceCount: Int = 0
    private var sessionId: UUID = UUID()  // Track current meditation session
    private static let meditationPitchMultiplier: Float = 0.6  // Slightly lower pitch for calmer voice

    // Track phrases for closed captioning
    private var allPhrases: [String] = []
    private var currentPhraseIndex: Int = 0

    // Reference to custom meditation manager for random selection
    weak var customMeditationManager: CustomMeditationManager?

    // Callback to notify when ambient volume changes
    var onAmbientVolumeChanged: ((Float) -> Void)? = nil
    
    let voiceVolume: Float = 0.25
    
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
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Self.meditationSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = voiceVolume
        utterance.pitchMultiplier = Self.meditationPitchMultiplier
        
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        
        synthesizer.speak(utterance)
    }
    
    func getRandomMeditation() -> String? {
        print("🎲 getRandomMeditation called")

        // Build pool of all available meditations (presets + customs)
        var allMeditations: [(text: String, source: String)] = []

        // Add all preset meditation files
        for i in 1...10 {
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
            print("❌ No meditations found (neither preset nor custom)")
            return nil
        }

        // Randomly select one meditation from the combined pool
        let selected = allMeditations.randomElement()!
        print("✅ Randomly selected '\(selected.source)' (\(selected.text.count) characters) from pool of \(allMeditations.count) meditations")

        return selected.text
    }
    
    /// Starts speaking a random meditation from text files
    func startSpeakingRandomMeditation() {
        guard !isSpeaking else { return }
        
        // Try to load a random meditation file
        guard let meditationText = loadRandomMeditationFile() else {
            print("No meditation files found")
            return
        }
        
        isSpeaking = true
        isCustomMode = true  // Treat like custom - play once, don't repeat
        
        let utterance = AVSpeechUtterance(string: meditationText)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Self.meditationSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = voiceVolume
        utterance.pitchMultiplier = Self.meditationPitchMultiplier
        
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        
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

        // Stop any currently playing meditation first
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // Reset counters but keep the playing state
        queuedUtteranceCount = 0
        repeatCount = 0
        sessionId = UUID()  // New session

        // Reset closed captioning
        currentPhrase = ""
        previousPhrase = ""
        allPhrases = []
        currentPhraseIndex = 0

        // IMPORTANT: Set state to "playing" IMMEDIATELY (synchronously) before the delay
        // This prevents race conditions where the UI thinks nothing is playing during the 50ms delay
        isSpeaking = true
        isPlayingMeditation = true
        isCustomMode = true

        // Small delay to ensure synthesizer is fully stopped and cleared
        // This prevents race conditions with delegate callbacks from stopped utterances
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }

            // Remove question marks to prevent voice inflection changes
            let textWithoutQuestions = text.replacingOccurrences(of: "?", with: "")

            // Check if text has any pause markers
            let hasPauseMarkers = textWithoutQuestions.range(of: #"\(\d+(?:\.\d+)?[sm]\)"#, options: .regularExpression) != nil

            // If no pause markers found, add automatic ones
            let processedText = hasPauseMarkers ? textWithoutQuestions : self.addAutomaticPauses(to: textWithoutQuestions)

            // Split by both newlines and pause markers
            let phrases = self.extractPhrasesWithPauses(from: processedText)

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

            // Store ULTRA-cleaned phrases for closed captioning (so VoiceOver doesn't read pause markers)
            self.allPhrases = ultraCleanedPhrases.map { $0.phrase }

            // Calculate total utterance count (speech + silent pause utterances)
            var totalUtteranceCount = 0
            for (ultraCleanPhrase, delay) in ultraCleanedPhrases {
                totalUtteranceCount += 1  // Count the speech utterance

                // Count silent pause utterances
                if delay > 0 {
                    let numPauses = Int(ceil(delay / 5.0))  // Break into 5-second chunks
                    totalUtteranceCount += numPauses
                }
            }

            // Set the count of ALL utterances we're about to queue (speech + silent)
            self.queuedUtteranceCount = totalUtteranceCount

            for (_, (ultraCleanPhrase, delay)) in ultraCleanedPhrases.enumerated() {
                let utterance = AVSpeechUtterance(string: ultraCleanPhrase)
                utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Self.meditationSpeechRate
                utterance.pitchMultiplier = 1.0
                utterance.volume = self.voiceVolume
                utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                utterance.pitchMultiplier = Self.meditationPitchMultiplier

                self.synthesizer.speak(utterance)

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
                        self.synthesizer.speak(silentUtterance)
                    }
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
        
    /// Loads a random meditation text file from the bundle (preset_meditation1.txt through preset_meditation10.txt only)
    private func loadRandomMeditationFile() -> String? {
        // Only load preset meditation files (preset_meditation1.txt through preset_meditation10.txt)
        var validURLs: [URL] = []
        
        for i in 1...10 {
            if let url = Bundle.main.url(forResource: "preset_meditation\(i)", withExtension: "txt") {
                validURLs.append(url)
            }
        }
        
        guard !validURLs.isEmpty else {
            print("No preset meditation files found")
            return nil
        }
        
        // Pick a random preset meditation file
        let randomURL = validURLs.randomElement()!
        
        // Load the text
        guard let text = try? String(contentsOf: randomURL, encoding: .utf8) else {
            print("Could not read preset meditation file")
            return nil
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Stops speaking immediately
    func stopSpeaking() {
        print("🛑 stopSpeaking called - current state: isSpeaking=\(isSpeaking), isPlayingMeditation=\(isPlayingMeditation)")
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        isPlayingMeditation = false
        repeatCount = 0
        queuedUtteranceCount = 0
        currentPhrase = ""
        previousPhrase = ""
        print("✅ stopSpeaking complete - state reset")
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
    fileprivate func didFinishSpeaking(_ utterance: AVSpeechUtterance) {
        // Ignore callbacks if we're not actually supposed to be speaking
        // This prevents stale callbacks from stopped utterances
        guard isSpeaking else {
            return
        }

        // If custom mode, decrement the queue counter
        if isCustomMode {
            // Extra safety: only decrement if count is positive
            // This prevents stale callbacks from causing negative counts
            guard queuedUtteranceCount > 0 else {
                return
            }

            queuedUtteranceCount -= 1

            // Only increment phrase index for actual speech (not silent utterances)
            if !utterance.speechString.isEmpty {
                currentPhraseIndex += 1  // Move to next phrase for closed captioning
            }

            // Only stop when all utterances are done
            if queuedUtteranceCount <= 0 {
                isSpeaking = false
                isPlayingMeditation = false
                isCustomMode = false
                queuedUtteranceCount = 0
                currentPhrase = ""
                previousPhrase = ""
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

    override init() {
        super.init()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            manager?.didStartUtterance(utterance)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            manager?.didFinishSpeaking(utterance)
        }
    }
}
