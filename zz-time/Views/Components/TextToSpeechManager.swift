import AVFoundation
import SwiftUI

/// A simple manager for text-to-speech using AVSpeechSynthesizer.
/// This uses the built-in iOS voices without requiring any downloads.
@MainActor
class TextToSpeechManager: ObservableObject {
    @Published var isSpeaking: Bool = false
    
    private static let meditationSpeechRate: Float = 0.45  // Calm, slow rate for meditation
    private let synthesizer = AVSpeechSynthesizer()
    private let speechDelegate: SpeechDelegate
    private var repeatCount = 0
    private let maxRepeats = 10
    private var isCustomMode: Bool = false
    
    init() {
        let delegate = SpeechDelegate()
        speechDelegate = delegate
        synthesizer.delegate = speechDelegate
        delegate.manager = self
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
        utterance.volume = 0.3
        
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        
        synthesizer.speak(utterance)
    }
    
    func getRandomMeditation() -> String? {
        // Try to load a random meditation file
        guard let meditationText = loadRandomMeditationFile() else {
            print("No meditation files found")
            return nil
        }
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
        utterance.volume = 0.3
        
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
    /// Starts speaking text with embedded pauses like "(4s)" – splits into utterances automatically
    func startSpeakingWithPauses(_ text: String) {
        guard !isSpeaking, !text.isEmpty else { return }
        
        isSpeaking = true
        isCustomMode = true
        
        // Check if text has any pause markers
        let hasPauseMarkers = text.range(of: #"\(\d+(?:\.\d+)?[sm]\)"#, options: .regularExpression) != nil
        
        // If no pause markers found, add automatic ones
        let processedText = hasPauseMarkers ? text : addAutomaticPauses(to: text)
        
        // Split by both newlines and pause markers
        // First, let's parse the text more carefully to handle mid-sentence pauses
        let phrases = extractPhrasesWithPauses(from: processedText)
        
        for (phrase, delay) in phrases {
            guard !phrase.isEmpty else { continue }
            
            let utterance = AVSpeechUtterance(string: phrase)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Self.meditationSpeechRate
            utterance.pitchMultiplier = 1.0
            utterance.volume = 0.3
            utterance.postUtteranceDelay = delay
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            
            synthesizer.speak(utterance)
        }
    }

    /// Extracts phrases and their associated pauses from text
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
        
    /// Loads a random meditation text file from the bundle (preset-meditation1.txt through preset-meditation10.txt only)
    private func loadRandomMeditationFile() -> String? {
        // Only load preset meditation files (preset-meditation1.txt through preset-meditation10.txt)
        var validURLs: [URL] = []
        
        for i in 1...10 {
            if let url = Bundle.main.url(forResource: "preset-meditation\(i)", withExtension: "txt") {
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
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        repeatCount = 0
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
        utterance.volume = 0.3
        
        // Use default US English voice
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        
        synthesizer.speak(utterance)
        repeatCount += 1
    }
    
    // Called by the delegate when speech finishes
    fileprivate func didFinishSpeaking() {
        // If custom mode, just stop - don't repeat
        if isCustomMode {
            isSpeaking = false
            isCustomMode = false
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
