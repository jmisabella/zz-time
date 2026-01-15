import AVFoundation
import Foundation

/// Manages voice selection and preferences for text-to-speech
/// Handles discovery of available voices, quality detection, and preference persistence
class VoiceManager {
    static let shared = VoiceManager()

    // UserDefaults keys
    private let preferredVoiceIdentifierKey = "preferredVoiceIdentifier"

    private init() {}

    /// The user's preferred voice identifier (if any)
    var preferredVoiceIdentifier: String? {
        get {
            UserDefaults.standard.string(forKey: preferredVoiceIdentifierKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: preferredVoiceIdentifierKey)
        }
    }

    /// List of voice names to exclude from all voice offerings
    /// These are novelty/robotic voices unsuitable for stories
    private let excludedVoiceNames: [String] = [
        "albert", "bad news", "bahh", "bells", "boing", "bubbles", "cellos",
        "eddy", "flo", "fred", "good news", "grandma", "grandpa", "jester",
        "junior", "kathy", "organ", "ralph", "reed", "rocko", "sandy",
        "superstar", "trinoids", "whisper", "wobble", "zarvox"
    ]

    /// Checks if a voice should be excluded based on the exclusion list
    private func isVoiceExcluded(_ voice: AVSpeechSynthesisVoice) -> Bool {
        let nameLower = voice.name.lowercased()

        for excludedName in excludedVoiceNames {
            if nameLower.contains(excludedName) {
                return true
            }
        }

        return false
    }

    /// Returns story-appropriate voices (all quality levels)
    /// Filters out novelty/robotic voices to ensure a calming experience
    /// For first-time users, a random voice from this list will be selected
    func getStoryAppropriateVoices() -> [AVSpeechSynthesisVoice] {
        // Get ALL English voices (includes compact/default, enhanced, and premium)
        let allEnglishVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }

        // Filter out excluded novelty voices
        let storyVoices = allEnglishVoices.filter { !isVoiceExcluded($0) }

        return storyVoices
    }

    /// Returns the voice to use for speech based on user preferences
    /// Priority order:
    /// 1. User's selected voice (if they have one saved)
    /// 2. Random selection from story-appropriate voices (for first-time users)
    /// 3. System default voice (fallback if no voices available - should never happen)
    func getPreferredVoice() -> AVSpeechSynthesisVoice? {
        // Check if user explicitly selected system default
        if let identifier = preferredVoiceIdentifier {
            if identifier == "SYSTEM_DEFAULT" {
                return AVSpeechSynthesisVoice(language: "en-US")
            }

            // Try to get the user's preferred voice
            if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
                return voice
            }

            // If we have a saved identifier but can't find the voice, it might have been deleted
            // Fall through to select a random voice but DON'T auto-save it
        }

        // For first-time users OR invalid saved voice: randomly select from story-appropriate voices
        let storyVoices = getStoryAppropriateVoices()

        if !storyVoices.isEmpty {
            // Use explicit random index selection
            let randomIndex = Int.random(in: 0..<storyVoices.count)
            let randomVoice = storyVoices[randomIndex]

            // DO NOT auto-save - only save when user explicitly selects a voice in settings
            // This prevents overwriting user's selection if their voice becomes temporarily unavailable

            return randomVoice
        }

        // Final fallback to system default if no voices available (should never happen)
        return AVSpeechSynthesisVoice(language: "en-US")
    }

    /// Returns all available English voices on the device (excluding novelty voices)
    func getAvailableEnglishVoices() -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") && !isVoiceExcluded($0) }
            .sorted { voice1, voice2 in
                // Sort by quality (premium > enhanced > default), then by name
                if voice1.quality.rawValue != voice2.quality.rawValue {
                    return voice1.quality.rawValue > voice2.quality.rawValue
                }
                return voice1.name < voice2.name
            }
    }

    /// Returns enhanced/premium English voices only (excluding novelty voices)
    func getEnhancedEnglishVoices() -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") &&
                      ($0.quality == .enhanced || $0.quality == .premium) &&
                      !isVoiceExcluded($0) }
            .sorted { $0.name < $1.name }
    }

    /// Returns a friendly display name for a voice
    func displayName(for voice: AVSpeechSynthesisVoice) -> String {
        // Extract locale code (e.g., "en-US" -> "US")
        let localeComponents = voice.language.components(separatedBy: "-")
        let region = localeComponents.count > 1 ? localeComponents[1] : ""

        // Format: "Name (Region)"
        if !region.isEmpty {
            return "\(voice.name) (\(region))"
        }
        return voice.name
    }

    /// Returns a quality badge string for display
    func qualityBadge(for voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .default:
            return "Default"
        case .enhanced:
            return "Enhanced"
        case .premium:
            return "Premium"
        @unknown default:
            return "Unknown"
        }
    }

    /// Returns estimated size string for a voice quality
    func estimatedSize(for quality: AVSpeechSynthesisVoiceQuality) -> String {
        switch quality {
        case .default:
            return "~50-100MB"
        case .enhanced:
            return "~100-300MB"
        case .premium:
            return "~300-500MB"
        @unknown default:
            return "Unknown"
        }
    }

    /// Checks if a voice appears to be downloaded and ready to use
    /// Note: iOS doesn't provide a direct API to check download status,
    /// so we do a best-effort check by attempting to create the voice
    func isVoiceAvailable(_ voice: AVSpeechSynthesisVoice) -> Bool {
        // Default quality voices are always available
        if voice.quality == .default {
            return true
        }

        // For enhanced/premium voices, we can't reliably detect if they're downloaded
        // iOS will automatically prompt to download when first used
        // For now, we'll assume enhanced/premium voices may need download
        return false
    }

    /// Returns the appropriate speech rate multiplier for a given voice
    /// Default voices use 0.8, enhanced/premium voices use 1.0
    func getSpeechRateMultiplier(for voice: AVSpeechSynthesisVoice?) -> Float {
        guard let voice = voice else {
            return 0.8  // Default for nil voice
        }

        // Enhanced and Premium voices sound better at normal speed
        if voice.quality == .enhanced || voice.quality == .premium {
            return 1.0
        }

        // Default quality voices need to be slowed down
        return 0.8
    }
}
