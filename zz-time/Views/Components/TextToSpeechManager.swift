import AVFoundation
import SwiftUI

/// A simple manager for text-to-speech using AVSpeechSynthesizer.
/// This uses the built-in iOS voices without requiring any downloads.
@MainActor
class TextToSpeechManager: ObservableObject {
    @Published var isSpeaking: Bool = false
    @Published var isPlayingMeditation: Bool = false
    @Published var audioBalance: Double = -1.0  // -1.0 (all ambient) to 1.0 (no ambient)
    
    private static let meditationSpeechRate: Float = 0.45  // Calm, slow rate for meditation
    private let synthesizer = AVSpeechSynthesizer()
    private let speechDelegate: SpeechDelegate
    private var repeatCount = 0
    private let maxRepeats = 10
    private var isCustomMode: Bool = false
    private var queuedUtteranceCount: Int = 0
    private var sessionId: UUID = UUID()  // Track current meditation session
    private static let meditationPitchMultiplier: Float = 0.75  // Slightly lower pitch for calmer voice

    
    // Callback to notify when ambient volume changes
    var onAmbientVolumeChanged: ((Float) -> Void)? = nil
    
    let voiceVolume: Float = 0.32
    
    var ambientVolume: Float {
        // Balance ranges from -1 (all ambient) to 1 (all voice)
        // At -1: ambient = 0.6 (all ambient)
        // At 0: ambient = 0.3 (50/50 mix)
        // At 1: ambient = 0.0
        let normalizedBalance = (audioBalance + 1.0) / 2.0  // Convert -1...1 to 0...1
        return Float((1.0 - normalizedBalance) * 0.6)
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
        // Try to load a random meditation file
        guard let meditationText = loadRandomMeditationFile() else {
            print("❌ No meditation files found")
            return nil
        }
        print("✅ Loaded meditation text with \(meditationText.count) characters")
        return meditationText
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
        print("🎯 startSpeakingWithPauses called with text length: \(text.count)")
        guard !text.isEmpty else {
            print("❌ Text is empty, returning")
            return
        }

        print("🛑 Current state - isSpeaking: \(isSpeaking), isPlayingMeditation: \(isPlayingMeditation), synthesizer.isSpeaking: \(synthesizer.isSpeaking)")

        // Stop any currently playing meditation first
        if synthesizer.isSpeaking {
            print("🛑 Stopping synthesizer...")
            synthesizer.stopSpeaking(at: .immediate)
        }

        // Reset counters but keep the playing state
        queuedUtteranceCount = 0
        repeatCount = 0
        sessionId = UUID()  // New session

        // IMPORTANT: Set state to "playing" IMMEDIATELY (synchronously) before the delay
        // This prevents race conditions where the UI thinks nothing is playing during the 50ms delay
        isSpeaking = true
        isPlayingMeditation = true
        isCustomMode = true

        print("✅ State set to playing, starting meditation after brief delay...")

        // Small delay to ensure synthesizer is fully stopped and cleared
        // This prevents race conditions with delegate callbacks from stopped utterances
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }

            print("🚀 Queueing meditation utterances...")

            // Check if text has any pause markers
            let hasPauseMarkers = text.range(of: #"\(\d+(?:\.\d+)?[sm]\)"#, options: .regularExpression) != nil

            // If no pause markers found, add automatic ones
            let processedText = hasPauseMarkers ? text : self.addAutomaticPauses(to: text)

            // Split by both newlines and pause markers
            // First, let's parse the text more carefully to handle mid-sentence pauses
            let phrases = self.extractPhrasesWithPauses(from: processedText)

            // Filter out empty phrases first
            let validPhrases = phrases.filter { !$0.phrase.isEmpty }

            print("📝 Extracted \(validPhrases.count) valid phrases")

            // Set the count of utterances we're about to queue
            self.queuedUtteranceCount = validPhrases.count

            for (index, (phrase, delay)) in validPhrases.enumerated() {
                let utterance = AVSpeechUtterance(string: phrase)
                utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Self.meditationSpeechRate
                utterance.pitchMultiplier = 1.0
                utterance.volume = self.voiceVolume
                utterance.postUtteranceDelay = delay
                utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                utterance.pitchMultiplier = Self.meditationPitchMultiplier

                print("🔊 Queueing utterance \(index + 1)/\(validPhrases.count): '\(phrase.prefix(30))...' (delay: \(delay)s)")
                self.synthesizer.speak(utterance)
            }

            print("✅ All \(validPhrases.count) utterances queued")
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
        
        // Split the entire text by pause markers
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        var lastIndex = text.startIndex
        
        for match in matches {
            // Get the phrase before this pause marker
            if let matchRange = Range(match.range, in: text) {
                let phraseBeforePause = String(text[lastIndex..<matchRange.lowerBound])
                
                // Get the pause duration and unit
                if let durationRange = Range(match.range(at: 1), in: text),
                   let unitRange = Range(match.range(at: 2), in: text),
                   let value = Double(text[durationRange]) {
                    
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
                }
                
                lastIndex = matchRange.upperBound
            }
        }
        
        // Add any remaining text after the last pause marker
        let remainingText = String(text[lastIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !remainingText.isEmpty {
            result.append((remainingText, 0.0))
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
    
    // Called by the delegate when speech finishes
    fileprivate func didFinishSpeaking() {
        print("🎤 didFinishSpeaking called - isSpeaking: \(isSpeaking), isCustomMode: \(isCustomMode), queuedCount: \(queuedUtteranceCount)")

        // Ignore callbacks if we're not actually supposed to be speaking
        // This prevents stale callbacks from stopped utterances
        guard isSpeaking else {
            print("⚠️ Ignoring callback - not in speaking state")
            return
        }

        // If custom mode, decrement the queue counter
        if isCustomMode {
            // Extra safety: only decrement if count is positive
            // This prevents stale callbacks from causing negative counts
            guard queuedUtteranceCount > 0 else {
                print("⚠️ Ignoring callback - queue count already at \(queuedUtteranceCount)")
                return
            }

            queuedUtteranceCount -= 1
            print("📉 Decremented queue count to \(queuedUtteranceCount)")

            // Only stop when all utterances are done
            if queuedUtteranceCount <= 0 {
                print("✅ All utterances complete - stopping")
                isSpeaking = false
                isPlayingMeditation = false
                isCustomMode = false
                queuedUtteranceCount = 0
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
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            manager?.didFinishSpeaking()
        }
    }
}
