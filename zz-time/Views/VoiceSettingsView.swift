import SwiftUI
import AVFoundation

struct VoiceSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var ttsManager: TextToSpeechManager
    @State private var selectedVoiceIdentifier: String? = VoiceManager.shared.preferredVoiceIdentifier
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []
    @State private var allVoiceOptions: [VoiceManager.VoiceOption] = []  // All curated voices
    @State private var previewingVoiceIdentifier: String? = nil  // Track which voice is being previewed
    @State private var wasStoryPlayingBeforePreview: Bool = false  // Track if story was playing

    // TTS for preview
    @State private var previewSynthesizer: AVSpeechSynthesizer? = nil
    @State private var previewDelegate: PreviewDelegate? = nil  // Retain delegate to prevent crash

    // Special identifier for system default voice
    private let systemDefaultIdentifier = "SYSTEM_DEFAULT"
    private let previewText = "Close your eyes and listen as words become worlds, stories unfold."

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
                            InfoRow(text: "All 7 curated voices shown below, even if not downloaded")
                            InfoRow(text: "Premium/Enhanced voices offer the best quality (100-500MB each)")
                            InfoRow(text: "Tap undownloaded voices to see where to get them")

                            Divider()
                                .padding(.vertical, 4)

                            Text("To download voices:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fontWeight(.semibold)

                            Button(action: {
                                // Open iOS Settings to voice download page
                                if let url = URL(string: "App-prefs:root=ACCESSIBILITY&path=SPEECH_SETTINGS") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.up.forward.app")
                                    Text("Settings → Accessibility → Read & Speak → Voices → English")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                            }
                            .padding(.leading, 8)

                            Text("Look for: Lee (Australia), Daniel (UK), Jamie (UK), Oliver (UK), Karen (Australia), Serena (UK), or Ava (US)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                                .padding(.top, 2)

                            Divider()
                                .padding(.vertical, 4)

                            Text("To delete voices and free up storage:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fontWeight(.semibold)

                            Text("In the same iOS Settings menu, swipe left on any voice to delete")
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

                        // All curated voice options (downloaded and not downloaded)
                        ForEach(allVoiceOptions, id: \.name) { voiceOption in
                            CuratedVoiceRow(
                                voiceOption: voiceOption,
                                isSelected: isVoiceOptionSelected(voiceOption),
                                isPreviewing: isVoiceOptionPreviewing(voiceOption),
                                onSelect: {
                                    selectVoiceOption(voiceOption)
                                },
                                onPreview: {
                                    if isVoiceOptionPreviewing(voiceOption) {
                                        stopPreview()
                                    } else {
                                        previewVoiceOption(voiceOption)
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
                                VoiceManager.shared.userExplicitlySelectedVoice = true
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
            // Refresh the selected voice from storage every time view appears
            selectedVoiceIdentifier = VoiceManager.shared.preferredVoiceIdentifier
            loadAvailableVoices()
            loadAllVoiceOptions()
        }
        .onDisappear {
            // Stop any playing preview and resume story if needed
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

    private func loadAllVoiceOptions() {
        allVoiceOptions = VoiceManager.shared.getAllCuratedVoiceOptions()
    }

    private func isVoiceOptionSelected(_ voiceOption: VoiceManager.VoiceOption) -> Bool {
        guard let selectedId = selectedVoiceIdentifier else { return false }

        // Check if any of the downloaded voices match the selected identifier
        return voiceOption.downloadedVoices.contains(where: { $0.identifier == selectedId })
    }

    private func isVoiceOptionPreviewing(_ voiceOption: VoiceManager.VoiceOption) -> Bool {
        guard let previewingId = previewingVoiceIdentifier else { return false }

        // Check if any of the downloaded voices match the previewing identifier
        return voiceOption.downloadedVoices.contains(where: { $0.identifier == previewingId })
    }

    private func selectVoiceOption(_ voiceOption: VoiceManager.VoiceOption) {
        // If voice is not downloaded, we can't select it
        guard voiceOption.hasAnyDownloaded else { return }

        // Select the best quality voice available
        if let bestVoice = voiceOption.downloadedVoices.max(by: { $0.quality.rawValue < $1.quality.rawValue }) {
            selectedVoiceIdentifier = bestVoice.identifier
            VoiceManager.shared.preferredVoiceIdentifier = bestVoice.identifier
            VoiceManager.shared.userExplicitlySelectedVoice = true
        }
    }

    private func previewVoiceOption(_ voiceOption: VoiceManager.VoiceOption) {
        // If voice is not downloaded, we can't preview it
        guard voiceOption.hasAnyDownloaded else { return }

        // Preview the best quality voice available
        if let bestVoice = voiceOption.downloadedVoices.max(by: { $0.quality.rawValue < $1.quality.rawValue }) {
            previewVoice(bestVoice)
        }
    }

    private func previewVoice(_ voice: AVSpeechSynthesisVoice) {
        // Stop any currently playing preview immediately
        previewSynthesizer?.stopSpeaking(at: .immediate)
        previewSynthesizer = nil
        previewDelegate = nil

        // Pause story if it's playing (only if not already paused)
        if ttsManager.isSpeaking && !wasStoryPlayingBeforePreview {
            wasStoryPlayingBeforePreview = true
            ttsManager.synthesizer.pauseSpeaking(at: .word)
        }

        previewingVoiceIdentifier = voice.identifier

        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: previewText)
        utterance.voice = voice

        // Use the same speech rate logic as actual story
        let speechRateMultiplier = VoiceManager.shared.getSpeechRateMultiplier(for: voice)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * speechRateMultiplier
        utterance.pitchMultiplier = 1.0  // Same as story pitch
        utterance.volume = ttsManager.voiceVolume  // Use same volume as story (0.25)

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

        // Resume story if it was playing before preview
        if wasStoryPlayingBeforePreview {
            ttsManager.synthesizer.continueSpeaking()
            wasStoryPlayingBeforePreview = false
        }
    }

    private func previewSystemDefault() {
        // Stop any currently playing preview immediately
        previewSynthesizer?.stopSpeaking(at: .immediate)
        previewSynthesizer = nil
        previewDelegate = nil

        // Pause story if it's playing (only if not already paused)
        if ttsManager.isSpeaking && !wasStoryPlayingBeforePreview {
            wasStoryPlayingBeforePreview = true
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

// MARK: - Curated Voice Row Component
struct CuratedVoiceRow: View {
    let voiceOption: VoiceManager.VoiceOption
    let isSelected: Bool
    let isPreviewing: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(voiceOption.displayName)
                        .font(.body)

                    Text("(\(voiceOption.gender))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    // Quality badge (if downloaded)
                    if let quality = voiceOption.bestQuality {
                        QualityBadge(quality: quality)
                    }

                    // Download status
                    if !voiceOption.hasAnyDownloaded {
                        // Not downloaded at all
                        HStack(spacing: 4) {
                            Image(systemName: "icloud.and.arrow.down")
                                .font(.caption)
                            Text("Not downloaded")
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                    } else if !voiceOption.isFullyDownloaded {
                        // Only compact/default downloaded
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle")
                                .font(.caption)
                            Text("Download for better quality")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            // Preview/Stop button - only enabled if voice is downloaded
            Button(action: onPreview) {
                Image(systemName: isPreviewing ? "stop.circle.fill" : "play.circle")
                    .font(.title2)
                    .foregroundColor(voiceOption.hasAnyDownloaded ? (isPreviewing ? .red : .blue) : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!voiceOption.hasAnyDownloaded)

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
            if voiceOption.hasAnyDownloaded {
                onSelect()
            }
        }
        .opacity(voiceOption.hasAnyDownloaded ? 1.0 : 0.6)
    }
}

// MARK: - Voice Row Component (Legacy - for backwards compatibility)
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
