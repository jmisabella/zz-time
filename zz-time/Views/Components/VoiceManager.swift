import AVFoundation
import Foundation

/// Manages voice selection and preferences for text-to-speech
/// Handles discovery of available voices, quality detection, and preference persistence
class VoiceManager {
    static let shared = VoiceManager()

    // UserDefaults keys
    private let useEnhancedVoiceKey = "useEnhancedVoice"
    private let preferredVoiceIdentifierKey = "preferredVoiceIdentifier"

    private init() {}

    /// Whether the user has enabled enhanced voice (default: false)
    var useEnhancedVoice: Bool {
        get {
            UserDefaults.standard.bool(forKey: useEnhancedVoiceKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: useEnhancedVoiceKey)
        }
    }

    /// The user's preferred voice identifier (if any)
    var preferredVoiceIdentifier: String? {
        get {
            UserDefaults.standard.string(forKey: preferredVoiceIdentifierKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: preferredVoiceIdentifierKey)
        }
    }

    /// Returns the voice to use for speech based on user preferences
    /// Priority order:
    /// 1. User's selected enhanced/premium voice (if enabled and available)
    /// 2. Any downloaded enhanced voice for "en-US" (if enhanced setting is on)
    /// 3. Default compact system voice (current behavior)
    func getPreferredVoice() -> AVSpeechSynthesisVoice? {
        // If enhanced voice is disabled, return default
        guard useEnhancedVoice else {
            return AVSpeechSynthesisVoice(language: "en-US")
        }

        // Try user's preferred voice
        if let identifier = preferredVoiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            return voice
        }

        // Fallback to any enhanced voice for English
        let enhancedVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") &&
                      ($0.quality == .enhanced || $0.quality == .premium) }

        if let voice = enhancedVoices.first {
            return voice
        }

        // Final fallback to default
        return AVSpeechSynthesisVoice(language: "en-US")
    }

    /// Returns all available English voices on the device
    func getAvailableEnglishVoices() -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { voice1, voice2 in
                // Sort by quality (premium > enhanced > default), then by name
                if voice1.quality.rawValue != voice2.quality.rawValue {
                    return voice1.quality.rawValue > voice2.quality.rawValue
                }
                return voice1.name < voice2.name
            }
    }

    /// Returns enhanced/premium English voices only
    func getEnhancedEnglishVoices() -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") &&
                      ($0.quality == .enhanced || $0.quality == .premium) }
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
