import AVFoundation
import SwiftUI

/// A simple manager for text-to-speech using AVSpeechSynthesizer.
/// This uses the built-in iOS voices without requiring any downloads.
@MainActor
class TextToSpeechManager: ObservableObject {
    @Published var isSpeaking: Bool = false
    
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
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.3
        
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        
        synthesizer.speak(utterance)
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
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.3
        
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        
        synthesizer.speak(utterance)
    }
        
        /// Loads a random meditation text file from the bundle
        private func loadRandomMeditationFile() -> String? {
            // Get all .txt files from the Meditations folder
            guard let urls = Bundle.main.urls(forResourcesWithExtension: "txt", subdirectory: nil) else {
                print("Meditations folder not found")
                return nil
            }
            
            guard !urls.isEmpty else {
                print("No meditation text files found")
                return nil
            }
            
            // Pick a random file
            let randomURL = urls.randomElement()!
            
            // Load the text
            guard let text = try? String(contentsOf: randomURL, encoding: .utf8) else {
                print("Could not read meditation file")
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
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
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
