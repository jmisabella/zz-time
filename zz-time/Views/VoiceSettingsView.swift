import SwiftUI
import AVFoundation

struct VoiceSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var useEnhancedVoice: Bool = VoiceManager.shared.useEnhancedVoice
    @State private var selectedVoiceIdentifier: String? = VoiceManager.shared.preferredVoiceIdentifier
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []
    @State private var isPreviewingVoice: Bool = false

    // TTS for preview
    @State private var previewSynthesizer: AVSpeechSynthesizer? = nil

    private let previewText = "Welcome to your meditation practice. Find a comfortable position and take a deep breath."

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Enhanced Voice Toggle
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "speaker.wave.3")
                                .font(.title2)
                                .foregroundColor(.blue)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Enhanced Voice")
                                    .font(.headline)
                                Text("Use higher-quality meditation voice")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Toggle("", isOn: $useEnhancedVoice)
                                .labelsHidden()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    // Voice Selection (only shown if enhanced voice is enabled)
                    if useEnhancedVoice {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Voice Selection")
                                .font(.headline)
                                .padding(.horizontal)

                            if availableVoices.isEmpty {
                                Text("No enhanced voices available. You can download voices in iOS Settings → Accessibility → Spoken Content → Voices")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding()
                            } else {
                                ForEach(availableVoices, id: \.identifier) { voice in
                                    VoiceRow(
                                        voice: voice,
                                        isSelected: selectedVoiceIdentifier == voice.identifier,
                                        onSelect: {
                                            selectedVoiceIdentifier = voice.identifier
                                            VoiceManager.shared.preferredVoiceIdentifier = voice.identifier
                                        },
                                        onPreview: {
                                            previewVoice(voice)
                                        },
                                        isPreviewing: isPreviewingVoice
                                    )
                                }
                            }
                        }
                    }

                    // Info Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("About Enhanced Voices")
                                .font(.headline)
                        }
                        .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(text: "Enhanced voices are downloaded by iOS, not by this app")
                            InfoRow(text: "Storage: Typically 100-500MB per voice")
                            InfoRow(text: "These are system-level voices stored in iOS settings")

                            Text("You can manage downloaded voices in:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)

                            Text("Settings → Accessibility → Spoken Content → Voices")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.leading, 8)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
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
        .onChange(of: useEnhancedVoice) { _, newValue in
            VoiceManager.shared.useEnhancedVoice = newValue

            // If turning off enhanced voice, clear the selected voice
            if !newValue {
                selectedVoiceIdentifier = nil
                VoiceManager.shared.preferredVoiceIdentifier = nil
            }
        }
        .onDisappear {
            // Stop any playing preview
            previewSynthesizer?.stopSpeaking(at: .immediate)
            previewSynthesizer = nil
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

        isPreviewingVoice = true

        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: previewText)
        utterance.voice = voice

        // Use the same speech rate logic as actual meditation
        let speechRateMultiplier = VoiceManager.shared.getSpeechRateMultiplier(for: voice)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * speechRateMultiplier
        utterance.pitchMultiplier = 1.0  // Same as meditation pitch
        utterance.volume = 0.5

        // Set up delegate to detect when preview finishes
        let delegate = PreviewDelegate {
            DispatchQueue.main.async {
                self.isPreviewingVoice = false
            }
        }
        synthesizer.delegate = delegate

        synthesizer.speak(utterance)
        previewSynthesizer = synthesizer

        // Safety timeout to reset preview state
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            if self.isPreviewingVoice {
                self.isPreviewingVoice = false
            }
        }
    }
}

// MARK: - Voice Row Component
struct VoiceRow: View {
    let voice: AVSpeechSynthesisVoice
    let isSelected: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void
    let isPreviewing: Bool

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

            // Preview button
            Button(action: onPreview) {
                Image(systemName: "play.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
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
