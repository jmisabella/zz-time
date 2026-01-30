import AVFoundation
import Foundation

/// Manages voice selection and preferences for text-to-speech
/// Handles discovery of available voices, quality detection, and preference persistence
class VoiceManager {
    static let shared = VoiceManager()

    // UserDefaults keys
    private let preferredVoiceIdentifierKey = "preferredVoiceIdentifier"
    private let userExplicitlySelectedVoiceKey = "userExplicitlySelectedVoice"

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

    /// Tracks whether user explicitly selected their voice via settings
    var userExplicitlySelectedVoice: Bool {
        get {
            UserDefaults.standard.bool(forKey: userExplicitlySelectedVoiceKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userExplicitlySelectedVoiceKey)
        }
    }

    /// Accept-list of voice names suitable for dark sci-fi story narration
    /// Only these curated voices will be available to users
    private let acceptedVoiceNames: [String] = [
        "lee",      // Male - Australian (current default priority)
        "daniel",   // Male - British (current default priority)
        "jamie",    // Male - British
        "oliver",   // Male - British
        "karen",    // Female - Australian
        "serena",   // Female - British
        "ava"       // Female - American
    ]

    /// Checks if a voice is on the accept-list
    private func isVoiceAccepted(_ voice: AVSpeechSynthesisVoice) -> Bool {
        let nameLower = voice.name.lowercased()

        for acceptedName in acceptedVoiceNames {
            if nameLower.contains(acceptedName) {
                return true
            }
        }

        return false
    }

    /// Returns the best available voice from the preferred hierarchy
    /// Priority order: Premium > Enhanced > Compact for each voice
    /// Voice order prioritizes Premium-capable voices first:
    /// Male: Lee (AU), Jamie (GB), Oliver (GB), Daniel (GB - Enhanced only, demoted)
    /// Female: Karen (AU), Serena (GB), Ava (US)
    private func getVoiceFromHierarchy() -> AVSpeechSynthesisVoice? {
        let preferredVoiceIdentifiers = [
            // Lee (AU) - Male, Australian - HAS PREMIUM
            "com.apple.voice.premium.en-AU.Lee",
            "com.apple.voice.enhanced.en-AU.Lee",
            "com.apple.voice.compact.en-AU.Lee",

            // Jamie (GB) - Male, British - HAS PREMIUM
            "com.apple.voice.premium.en-GB.Jamie",
            "com.apple.voice.enhanced.en-GB.Jamie",
            "com.apple.voice.compact.en-GB.Jamie",

            // Oliver (GB) - Male, British - HAS PREMIUM
            "com.apple.voice.premium.en-GB.Oliver",
            "com.apple.voice.enhanced.en-GB.Oliver",
            "com.apple.voice.compact.en-GB.Oliver",

            // Daniel (GB) - Male, British - NO PREMIUM (demoted)
            "com.apple.voice.enhanced.en-GB.Daniel",
            "com.apple.voice.compact.en-GB.Daniel",

            // Karen (AU) - Female, Australian - HAS PREMIUM
            "com.apple.voice.premium.en-AU.Karen",
            "com.apple.voice.enhanced.en-AU.Karen",
            "com.apple.voice.compact.en-AU.Karen",

            // Serena (GB) - Female, British - HAS PREMIUM
            "com.apple.voice.premium.en-GB.Serena",
            "com.apple.voice.enhanced.en-GB.Serena",
            "com.apple.voice.compact.en-GB.Serena",

            // Ava (US) - Female, American - HAS PREMIUM
            "com.apple.voice.premium.en-US.Ava",
            "com.apple.voice.enhanced.en-US.Ava",
            "com.apple.voice.compact.en-US.Ava"
        ]

        for identifier in preferredVoiceIdentifiers {
            if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
                return voice
            }
        }

        return nil  // None from hierarchy available
    }

    /// Returns story-appropriate voices (all quality levels)
    /// Uses accept-list to only include curated voices suitable for dark sci-fi narration
    /// For first-time users, a random voice from this list will be selected
    func getStoryAppropriateVoices() -> [AVSpeechSynthesisVoice] {
        // Get ALL English voices (includes compact/default, enhanced, and premium)
        let allEnglishVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }

        // Filter using accept-list - only curated voices
        let storyVoices = allEnglishVoices.filter { isVoiceAccepted($0) }

        return storyVoices
    }

    /// Returns the voice to use for speech based on user preferences
    /// Priority order:
    /// 1. User's explicitly selected voice (if they manually chose one in settings)
    /// 2. Voice hierarchy (Lee AU Premium/Enhanced/Default, then Daniel GB Premium/Enhanced/Default)
    /// 3. Previously auto-selected voice (if still valid)
    /// 4. Random selection from story-appropriate voices (fallback)
    /// 5. System default voice (final fallback if no voices available - should never happen)
    func getPreferredVoice() -> AVSpeechSynthesisVoice? {
        // STEP 1: Check if user explicitly selected a voice
        if userExplicitlySelectedVoice, let identifier = preferredVoiceIdentifier {
            // User made an explicit choice - honor it completely
            if identifier == "SYSTEM_DEFAULT" {
                return AVSpeechSynthesisVoice(language: "en-US")
            }

            if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
                return voice
            }

            // User's voice no longer available - clear the explicit flag and fall through
            userExplicitlySelectedVoice = false
        }

        // STEP 2: Try voice hierarchy (for new users or users who haven't explicitly chosen)
        if let hierarchyVoice = getVoiceFromHierarchy() {
            return hierarchyVoice
        }

        // STEP 3: Check if we have a previously auto-selected voice that's still valid
        if let identifier = preferredVoiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            return voice
        }

        // STEP 4: Fallback to random story-appropriate voice
        let storyVoices = getStoryAppropriateVoices()
        if !storyVoices.isEmpty {
            let randomIndex = Int.random(in: 0..<storyVoices.count)
            return storyVoices[randomIndex]
        }

        // STEP 5: Final fallback to system default
        return AVSpeechSynthesisVoice(language: "en-US")
    }

    /// Returns all available English voices on the device (only accept-listed voices)
    func getAvailableEnglishVoices() -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") && isVoiceAccepted($0) }
            .sorted { voice1, voice2 in
                // Sort by quality (premium > enhanced > default), then by name
                if voice1.quality.rawValue != voice2.quality.rawValue {
                    return voice1.quality.rawValue > voice2.quality.rawValue
                }
                return voice1.name < voice2.name
            }
    }

    /// Returns enhanced/premium English voices only (only accept-listed voices)
    func getEnhancedEnglishVoices() -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") &&
                      ($0.quality == .enhanced || $0.quality == .premium) &&
                      isVoiceAccepted($0) }
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

    /// Represents a curated voice option with metadata
    struct VoiceOption {
        let name: String                          // e.g., "Lee", "Daniel"
        let displayName: String                   // e.g., "Lee (AU)", "Daniel (UK)"
        let locale: String                        // e.g., "en-AU", "en-GB"
        let gender: String                        // "Male" or "Female"
        let downloadedVoices: [AVSpeechSynthesisVoice]  // Voices that are currently downloaded
        let bestQuality: AVSpeechSynthesisVoiceQuality?  // Best quality available (nil if none downloaded)

        var isFullyDownloaded: Bool {
            // Check if at least Enhanced or Premium is downloaded
            return downloadedVoices.contains(where: { $0.quality == .enhanced || $0.quality == .premium })
        }

        var hasAnyDownloaded: Bool {
            return !downloadedVoices.isEmpty
        }
    }

    /// Returns all curated voice options (both downloaded and not downloaded)
    func getAllCuratedVoiceOptions() -> [VoiceOption] {
        let curatedVoiceDefinitions: [(name: String, locale: String, displayName: String, gender: String)] = [
            ("Lee", "en-AU", "Lee (AU)", "Male"),
            ("Daniel", "en-GB", "Daniel (UK)", "Male"),
            ("Jamie", "en-GB", "Jamie (UK)", "Male"),
            ("Oliver", "en-GB", "Oliver (UK)", "Male"),
            ("Karen", "en-AU", "Karen (AU)", "Female"),
            ("Serena", "en-GB", "Serena (UK)", "Female"),
            ("Ava", "en-US", "Ava (US)", "Female")
        ]

        // Get all currently downloaded voices
        let downloadedVoices = AVSpeechSynthesisVoice.speechVoices()

        var voiceOptions: [VoiceOption] = []

        for definition in curatedVoiceDefinitions {
            // Find all downloaded variations of this voice (premium, enhanced, compact)
            let matchingVoices = downloadedVoices.filter { voice in
                voice.name.lowercased().contains(definition.name.lowercased()) &&
                voice.language.hasPrefix(definition.locale)
            }

            // Determine best quality available
            let bestQuality = matchingVoices.max(by: { $0.quality.rawValue < $1.quality.rawValue })?.quality

            let option = VoiceOption(
                name: definition.name,
                displayName: definition.displayName,
                locale: definition.locale,
                gender: definition.gender,
                downloadedVoices: matchingVoices,
                bestQuality: bestQuality
            )

            voiceOptions.append(option)
        }

        return voiceOptions
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
