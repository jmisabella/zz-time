import SwiftUI
import AVFoundation

struct VoiceSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var ttsManager: TextToSpeechManager
    @State private var selectedVoiceIdentifier: String? = VoiceManager.shared.preferredVoiceIdentifier
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []
    @State private var previewingVoiceIdentifier: String? = nil  // Track which voice is being previewed
    @State private var wasMeditationPlayingBeforePreview: Bool = false  // Track if meditation was playing

    // TTS for preview
    @State private var previewSynthesizer: AVSpeechSynthesizer? = nil
    @State private var previewDelegate: PreviewDelegate? = nil  // Retain delegate to prevent crash

    // Special identifier for system default voice
    private let systemDefaultIdentifier = "SYSTEM_DEFAULT"
    private let previewText = "Welcome to your meditation practice. Find a comfortable position and take a deep breath."

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Info Section (moved to top)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("About Voices")
                                .font(.headline)
                        }
                        .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(text: "Many enhanced voices come pre-installed on newer devices")
                            InfoRow(text: "Some voices may require download (100-500MB each)")

                            Text("To download or delete voices:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)

                            Text("Settings → Accessibility → Spoken Content → Voices")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.leading, 8)

                            Text("Swipe left on any voice to delete and free up storage")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    // Voice Selection Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Voice")
                            .font(.headline)
                            .padding(.horizontal)

                        // Enhanced/Premium voices
                        ForEach(availableVoices, id: \.identifier) { voice in
                            VoiceRow(
                                voice: voice,
                                isSelected: selectedVoiceIdentifier == voice.identifier,
                                isPreviewing: previewingVoiceIdentifier == voice.identifier,
                                onSelect: {
                                    selectedVoiceIdentifier = voice.identifier
                                    VoiceManager.shared.preferredVoiceIdentifier = voice.identifier
                                },
                                onPreview: {
                                    if previewingVoiceIdentifier == voice.identifier {
                                        stopPreview()
                                    } else {
                                        previewVoice(voice)
                                    }
                                }
                            )
                        }

                        // System Default Voice option (at the bottom)
                        SystemDefaultVoiceRow(
                            isSelected: selectedVoiceIdentifier == systemDefaultIdentifier,
                            isPreviewing: previewingVoiceIdentifier == systemDefaultIdentifier,
                            onSelect: {
                                selectedVoiceIdentifier = systemDefaultIdentifier
                                VoiceManager.shared.preferredVoiceIdentifier = systemDefaultIdentifier
                            },
                            onPreview: {
                                if previewingVoiceIdentifier == systemDefaultIdentifier {
                                    stopPreview()
                                } else {
                                    previewSystemDefault()
                                }
                            }
                        )
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Voice Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadAvailableVoices()
        }
        .onDisappear {
            // Stop any playing preview and resume meditation if needed
            stopPreview()
        }
    }

    private func loadAvailableVoices() {
        // Load all enhanced/premium English voices
        availableVoices = VoiceManager.shared.getEnhancedEnglishVoices()

        // If no voices found, also check all English voices (in case only default are available)
        if availableVoices.isEmpty {
            availableVoices = VoiceManager.shared.getAvailableEnglishVoices()
        }
    }

    private func previewVoice(_ voice: AVSpeechSynthesisVoice) {
        // Stop any currently playing preview immediately
        previewSynthesizer?.stopSpeaking(at: .immediate)
        previewSynthesizer = nil
        previewDelegate = nil

        // Pause meditation if it's playing (only if not already paused)
        if ttsManager.isSpeaking && !wasMeditationPlayingBeforePreview {
            wasMeditationPlayingBeforePreview = true
            ttsManager.synthesizer.pauseSpeaking(at: .word)
        }

        previewingVoiceIdentifier = voice.identifier

        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: previewText)
        utterance.voice = voice

        // Use the same speech rate logic as actual meditation
        let speechRateMultiplier = VoiceManager.shared.getSpeechRateMultiplier(for: voice)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * speechRateMultiplier
        utterance.pitchMultiplier = 1.0  // Same as meditation pitch
        utterance.volume = ttsManager.voiceVolume  // Use same volume as meditation (0.25)

        // Set up delegate to detect when preview finishes - MUST be retained!
        let delegate = PreviewDelegate {
            DispatchQueue.main.async {
                self.stopPreview()
            }
        }
        synthesizer.delegate = delegate

        // Store both synthesizer and delegate to prevent deallocation crash
        previewSynthesizer = synthesizer
        previewDelegate = delegate

        synthesizer.speak(utterance)
    }

    private func stopPreview() {
        // Stop the preview synthesizer
        previewSynthesizer?.stopSpeaking(at: .immediate)
        previewSynthesizer = nil
        previewDelegate = nil
        previewingVoiceIdentifier = nil

        // Resume meditation if it was playing before preview
        if wasMeditationPlayingBeforePreview {
            ttsManager.synthesizer.continueSpeaking()
            wasMeditationPlayingBeforePreview = false
        }
    }

    private func previewSystemDefault() {
        // Stop any currently playing preview immediately
        previewSynthesizer?.stopSpeaking(at: .immediate)
        previewSynthesizer = nil
        previewDelegate = nil

        // Pause meditation if it's playing (only if not already paused)
        if ttsManager.isSpeaking && !wasMeditationPlayingBeforePreview {
            wasMeditationPlayingBeforePreview = true
            ttsManager.synthesizer.pauseSpeaking(at: .word)
        }

        previewingVoiceIdentifier = systemDefaultIdentifier

        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: previewText)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")

        // Use default speech rate multiplier
        let speechRateMultiplier = VoiceManager.shared.getSpeechRateMultiplier(for: nil)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * speechRateMultiplier
        utterance.pitchMultiplier = 1.0
        utterance.volume = ttsManager.voiceVolume

        // Set up delegate to detect when preview finishes - MUST be retained!
        let delegate = PreviewDelegate {
            DispatchQueue.main.async {
                self.stopPreview()
            }
        }
        synthesizer.delegate = delegate

        // Store both synthesizer and delegate to prevent deallocation crash
        previewSynthesizer = synthesizer
        previewDelegate = delegate

        synthesizer.speak(utterance)
    }
}

// MARK: - Voice Row Component
struct VoiceRow: View {
    let voice: AVSpeechSynthesisVoice
    let isSelected: Bool
    let isPreviewing: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(VoiceManager.shared.displayName(for: voice))
                    .font(.body)

                HStack(spacing: 8) {
                    // Quality badge
                    QualityBadge(quality: voice.quality)

                    // Download status (for non-default voices)
                    if voice.quality != .default {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle")
                                .font(.caption)
                            Text("May need download")
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            // Preview/Stop button - changes based on isPreviewing state
            Button(action: onPreview) {
                Image(systemName: isPreviewing ? "stop.circle.fill" : "play.circle")
                    .font(.title2)
                    .foregroundColor(isPreviewing ? .red : .blue)
            }
            .buttonStyle(PlainButtonStyle())

            // Selection indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .gray)
                .font(.title3)
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - System Default Voice Row Component
struct SystemDefaultVoiceRow: View {
    let isSelected: Bool
    let isPreviewing: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("System Default")
                    .font(.body)

                HStack(spacing: 8) {
                    // Badge for system default
                    Text("Built-in")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.gray)
                        .cornerRadius(6)

                    Text("Always available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Preview/Stop button - changes based on isPreviewing state
            Button(action: onPreview) {
                Image(systemName: isPreviewing ? "stop.circle.fill" : "play.circle")
                    .font(.title2)
                    .foregroundColor(isPreviewing ? .red : .blue)
            }
            .buttonStyle(PlainButtonStyle())

            // Selection indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .gray)
                .font(.title3)
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Quality Badge Component
struct QualityBadge: View {
    let quality: AVSpeechSynthesisVoiceQuality

    var badgeColor: Color {
        switch quality {
        case .default:
            return .gray
        case .enhanced:
            return .green
        case .premium:
            return .purple
        @unknown default:
            return .gray
        }
    }

    var badgeText: String {
        switch quality {
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

    var body: some View {
        Text(badgeText)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor.opacity(0.2))
            .foregroundColor(badgeColor)
            .cornerRadius(6)
    }
}

// MARK: - Info Row Component
struct InfoRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview Delegate
private class PreviewDelegate: NSObject, AVSpeechSynthesizerDelegate {
    let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        super.init()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onFinish()
    }
}
