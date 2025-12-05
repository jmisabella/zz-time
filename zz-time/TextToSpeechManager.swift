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
        repeatCount = 0
        speakNextPhrase()
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
        utterance.volume = 0.8
        
        // Use default US English voice
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        
        synthesizer.speak(utterance)
        repeatCount += 1
    }
    
    // Called by the delegate when speech finishes
    fileprivate func didFinishSpeaking() {
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
