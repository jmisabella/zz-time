import SwiftUI

struct ExpandingView: View {
    // Centralized dimming duration in minutes
    private let defaultDimDurationMinutes: Double = 10

    // Computed property to convert minutes to seconds
    private var defaultDimDurationSeconds: Double {
        defaultDimDurationMinutes * 60
    }

    let color: Color
    let dismiss: () -> Void
    @Binding var durationMinutes: Double
    @Binding var isAlarmActive: Bool
    let changeRoom: (Int) -> Void
    let currentIndex: Int
    let maxIndex: Int
    let selectAlarm: () -> Void
    var onAmbientVolumeChanged: ((Float) -> Void)? = nil  // Callback to update ambient volume

    @State private var showLabel: Bool = false
    @State private var showBalanceLabel: Bool = false
    @State private var dimOverlayOpacity: Double = 0.0
    @State private var flashOverlayOpacity: Double = 0.0
    @State private var dimMode: DimMode = .duration(0)  // Will be set in onAppear
    @State private var roomChangeTrigger: Bool = false
    @State private var showTimePicker: Bool = false
    @State private var tempWakeTime: Date = Date()
    @State private var usePlasmaStyle: Bool = Bool.random()
    @State private var remainingTimer: Timer? = nil
    // Text-to-speech manager
    @StateObject private var ttsManager = TextToSpeechManager()

    // Custom story manager
    @StateObject private var storyManager = CustomStoryManager()

    // Custom poem manager
    @StateObject private var poemManager = CustomPoemManager()

    @State private var showContentBrowser: Bool = false

    // Voice settings
    @State private var showVoiceSettings: Bool = false

    // Closed captioning toggle
    @AppStorage("showStoryText") private var showStoryText: Bool = true

    // Crossfade loading state
    @State private var isCrossfading: Bool = false

    // MARK: - Helper Functions for Content Mode

    private func iconForContentMode(_ mode: ContentMode, isPlaying: Bool, isCrossfading: Bool) -> String {
        // Show loading indicator during crossfade
        if isCrossfading {
            return "ellipsis.circle.fill"
        }

        switch mode {
        case .off:
            return "leaf"
        case .story:
            return isPlaying ? "leaf.fill" : "leaf"
        case .poetry:
            return isPlaying ? "theatermasks.fill" : "theatermasks"
        }
    }

    private func colorForContentMode(_ mode: ContentMode, isPlaying: Bool, isCrossfading: Bool) -> Color {
        // Show grey color during crossfade
        if isCrossfading {
            return Color(white: 0.7)
        }

        switch mode {
        case .off:
            return Color(white: 0.7)
        case .story:
            return isPlaying ? Color.green : Color(white: 0.7)
        case .poetry:
            return isPlaying ? Color.purple : Color(white: 0.7)
        }
    }

    private func crossfadeToNextContent() {
        let currentMode = ttsManager.currentContentMode
        let nextMode = currentMode.next()

        // Get next content
        let nextText: String?
        switch nextMode {
        case .story:
            nextText = ttsManager.getSequentialStory()
        case .poetry:
            nextText = ttsManager.getRandomPoem()
            print("🎭 Poetry mode - got poem text: \(nextText != nil)")
        case .off:
            nextText = nil
        }

        guard let text = nextText else {
            print("❌ Crossfade failed - no content for mode: \(nextMode)")
            return
        }

        // Show loading indicator only when transitioning from story to poetry
        if currentMode == .story && nextMode == .poetry {
            isCrossfading = true
        }

        // Crossfade implementation (AVSpeechSynthesizer limitation: no real-time volume)
        Task {
            await ttsManager.stopSpeaking()

            // 1.5 second gap for natural transition
            try? await Task.sleep(nanoseconds: 1_500_000_000)

            // Update mode and start new content
            ttsManager.currentContentMode = nextMode
            UserDefaults.standard.set(nextMode.rawValue, forKey: "contentMode")
            if nextMode != .off {
                UserDefaults.standard.set(nextMode.rawValue, forKey: "lastContentMode")
            }

            // Clear loading state before starting new content
            isCrossfading = false

            ttsManager.startSpeakingWithPauses(text)
        }
    }

    // Dictionary to map room indices (30-34) to custom titles
    private let customRoomTitles: [Int: String] = [
        30: "Satie: Trois Gymnopédies: No. 1, Lent et douloureux",
        31: "J.S. Bach: Two-Part Invention No. 6 in E Major, BWV 777",
        32: "Chopin: Prelude No. 2 in A minor, Op. 28, Lento",
        //        33: "Ravel: Piano Concerto in G Major, M. 83 – II. Adagio assai",
        33: "J.S. Bach: Goldberg Variations 15, BWV 988",
        34: "Schubert: Sonata No. 6 in E minor, II. Allegretto (excerpt)",
    ]

    // Detect device orientation
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ZStack {
                    if usePlasmaStyle {
                        PlasmaBackground(color: color).ignoresSafeArea()
                    } else {
                        BreathingBackground(color: color).ignoresSafeArea()
                    }

                    Rectangle()
                        .fill(
                            isAlarmActive
                            ? Color(hue: 0.58, saturation: 0.3, brightness: 0.9)
                            : .black
                        )
                        .opacity(dimOverlayOpacity)
                        .ignoresSafeArea()

                    Rectangle()
                        .fill(Color.white)
                        .opacity(flashOverlayOpacity)
                        .ignoresSafeArea()
                }

                ZStack {
                    VStack {
                        // Duration slider
                        CustomSlider(
                        value: $durationMinutes,
                        minValue: 0,
                        maxValue: 1440,  // 24 hours in minutes
                        step: 1,
                        onEditingChanged: { editing in
                            showLabel = editing
                        }
                    )
                    .padding(.horizontal, 40)
                    .padding(.top, isLandscape ? 10 : 0) // Add top padding in landscape

                    // Audio balance slider
                    BalanceSlider(
                        value: $ttsManager.audioBalance,
                        onEditingChanged: { editing in
                            showBalanceLabel = editing
                        }
                    )
                    .padding(.horizontal, 40)
                    .padding(.top, isLandscape ? 4 : 8) // Reduce spacing in landscape
                    .onChange(of: ttsManager.audioBalance) { _, _ in
                        ttsManager.updateVolumesFromBalance()
                    }

                    if showBalanceLabel {
                        let balanceText: String = {
                            let ambientPercent = Int(ttsManager.audioBalance * 100)
                            return "ambient \(ambientPercent)%"
                        }()

                        Text(balanceText)
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                    }

                    Spacer()

                    Text(
                        customRoomTitles[currentIndex] ?? "room \(currentIndex + 1)"
                    )
                    .font(.system(size: 14, weight: .light, design: .rounded))
                    .foregroundColor(
                        (currentIndex < 10) ? Color(white: 0.7) : Color(white: 0.3)
                    )
                    .padding(.bottom, isLandscape ? 10 : 20) // Reduce spacing in landscape

                    HStack(spacing: 30) {
                    Button {
                        showVoiceSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.title)
                            .foregroundColor(Color(white: 0.7))
                            .padding(10)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .contentShape(Circle())

                    Button {
                        showContentBrowser = true
                    } label: {
                        Image(systemName: "text.quote")
                            .font(.title)
                            .foregroundColor(Color(white: 0.7))
                            .padding(10)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .contentShape(Circle())

                    Button {
                        let now = Date()
                        let calendar = Calendar.current
                        if let hour = UserDefaults.standard.object(
                            forKey: "preferredWakeHour"
                        ) as? Int,
                           let minute = UserDefaults.standard.object(
                            forKey: "preferredWakeMinute"
                           ) as? Int
                        {
                            tempWakeTime =
                            calendar.date(
                                bySettingHour: hour,
                                minute: minute,
                                second: 0,
                                of: now
                            ) ?? now
                        } else {
                            tempWakeTime =
                            calendar.date(
                                byAdding: .hour,
                                value: 8,
                                to: now
                            ) ?? now
                        }
                        showTimePicker = true
                    } label: {
                        Image(systemName: "clock")
                            .font(.title)
                        //                            .scaleEffect(1.2)
                            .foregroundColor(Color(white: 0.7))
                            .padding(10)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .contentShape(Circle())
                    // Leaf/Theater Masks button for content control
                    Button {} label: {
                        Image(systemName: iconForContentMode(ttsManager.currentContentMode, isPlaying: ttsManager.isSpeaking, isCrossfading: isCrossfading))
                        .font(.title)
                        .foregroundColor(colorForContentMode(ttsManager.currentContentMode, isPlaying: ttsManager.isSpeaking, isCrossfading: isCrossfading))
                        .symbolEffect(.pulse, options: .repeating, isActive: isCrossfading)
                        .padding(10)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .contentShape(Circle())
                    .simultaneousGesture(
                        TapGesture().onEnded { _ in
                            switch ttsManager.storyState {
                            case .idle:
                                // Cycle to next mode and start content
                                ttsManager.cycleContentMode()

                                switch ttsManager.currentContentMode {
                                case .story:
                                    guard let text = ttsManager.getSequentialStory() else { return }
                                    ttsManager.startSpeakingWithPauses(text)
                                case .poetry:
                                    guard let text = ttsManager.getRandomPoem() else { return }
                                    ttsManager.startSpeakingWithPauses(text)
                                case .off:
                                    break
                                }

                            case .playing:
                                // Check if cycling to next content or stopping
                                let nextMode = ttsManager.currentContentMode.next()

                                if nextMode == .off {
                                    // Stop completely
                                    Task {
                                        await ttsManager.stopSpeaking()
                                        ttsManager.currentContentMode = .off
                                        UserDefaults.standard.set("off", forKey: "contentMode")
                                    }
                                } else {
                                    // Crossfade to next content type
                                    crossfadeToNextContent()
                                }

                            case .starting, .stopping:
                                // Ignore clicks during transitions
                                break
                            }
                        }
                    )
                }
                .padding(.bottom, isLandscape ? 10 : 0) // Add bottom padding in landscape to keep buttons on screen

                }

                // Duration label overlay - appears on top without affecting layout
                if showLabel {
                    VStack {
                        let text: String = {
                            if durationMinutes == 0 {
                                return "infinite"
                            } else if durationMinutes < 60 {
                                let minutes = Int(durationMinutes)
                                return "\(minutes) minute\(minutes == 1 ? "" : "s")"
                            } else {
                                let hours = Int(durationMinutes / 60)
                                let minutes = Int(
                                    durationMinutes.truncatingRemainder(
                                        dividingBy: 60
                                    )
                                )
                                if minutes == 0 {
                                    return "\(hours) hour\(hours == 1 ? "" : "s")"
                                } else {
                                    return
                                    "\(hours) hour\(hours == 1 ? "" : "s"), \(minutes) minute\(minutes == 1 ? "" : "s")"
                                }
                            }
                        }()

                        Text(text)
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                            .padding(.top, 60)

                        Spacer()
                    }
                }
            }

            // Story text display in modal window above room label and buttons
            if showStoryText && ttsManager.isPlayingStory {
                VStack {
                    Spacer()
                    ScrollableStoryTextDisplay(
                        phraseHistory: ttsManager.phraseHistory,
                        currentPhrase: ttsManager.currentPhrase,
                        hasNewContent: $ttsManager.hasNewCaptionContent
                    )
                    .padding(.bottom, isLandscape ? 80 : 180) // Reduce bottom padding in landscape
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                .allowsHitTesting(true)  // Allow scrolling in the caption area
            }

            // Skip buttons for story mode (only when story/Leaf mode is active)
            if ttsManager.currentContentMode == .story {
                VStack {
                    Spacer()
                    HStack(spacing: 0) {
                        Button {
                            ttsManager.skipToPreviousChapter()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(10)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .contentShape(Circle())

                        Spacer()

                        Button {
                            ttsManager.skipToNextChapter()
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(10)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .contentShape(Circle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, isLandscape ? 60 : 120) // Reduce padding in landscape
                }
            }
            }
        }
        .gesture(
            SimultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            dismiss()
                        }
                    },
                DragGesture(minimumDistance: 20, coordinateSpace: .global)
                    .onEnded { value in
                        let translationHeight = value.translation.height
                        let translationWidth = value.translation.width
                        if translationHeight < -50 {
                            selectAlarm()
                        } else if translationHeight > 100 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                dismiss()
                            }
                        } else if translationWidth < -50 {
                            changeRoom(1)
                            roomChangeTrigger.toggle()
                        } else if translationWidth > 50 {
                            changeRoom(-1)
                            roomChangeTrigger.toggle()
                        }
                    }
            )
        )
        .onAppear {
            // Set up the ambient volume callback
            ttsManager.onAmbientVolumeChanged = onAmbientVolumeChanged
            ttsManager.updateVolumesFromBalance()

            // Connect the custom story manager to the TTS manager
            // This allows the leaf button to randomly select from preset stories
            ttsManager.customStoryManager = storyManager

            // Connect the custom poem manager to the TTS manager
            // This allows the theater masks button to randomly select from preset poems
            ttsManager.customPoemManager = poemManager

            // Do NOT auto-restore poetry/story mode when entering a room
            // User must explicitly activate it via the buttons

            dimMode = .duration(defaultDimDurationSeconds)
            if case .duration(let seconds) = dimMode {
                flashOverlayOpacity = 0
                withAnimation(.linear(duration: seconds)) {
                    dimOverlayOpacity = 1
                }
            }
            // Always check lastWakeTime, even if past
            if let wakeDate = UserDefaults.standard.object(
                forKey: "lastWakeTime"
            ) as? Date {
                updateDurationToRemaining()  // Clear stale duration if past
                // After update, check if wake time is still future
                if let updatedWakeDate = UserDefaults.standard.object(
                    forKey: "lastWakeTime"
                ) as? Date,
                   updatedWakeDate > Date()
                {
                    updateDurationToRemaining()  // Ensure sync
                    remainingTimer = Timer.scheduledTimer(
                        withTimeInterval: 60,
                        repeats: true
                    ) { _ in
                        updateDurationToRemaining()
                    }
                }
            }
        }
        .onDisappear {
            remainingTimer?.invalidate()
            remainingTimer = nil
            Task {
                await ttsManager.stopSpeaking()
            }
        }
        .onChange(of: isAlarmActive) { _, newValue in
            if newValue {
                withAnimation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
                ) {
                    dimOverlayOpacity = 0.8
                }
            } else {
                withAnimation(.none) {
                    dimOverlayOpacity = 0
                }
                if case .duration(let seconds) = dimMode {
                    withAnimation(.linear(duration: seconds)) {
                        dimOverlayOpacity = 1
                    }
                }
            }
        }
        .onChange(of: roomChangeTrigger) { _, _ in
            flashOverlayOpacity = 0.8
            dimOverlayOpacity = 0
            withAnimation(.linear(duration: 0.5)) {
                flashOverlayOpacity = 0
            }
            if case .duration(let seconds) = dimMode {
                withAnimation(.linear(duration: seconds)) {
                    dimOverlayOpacity = 1
                }
            }
        }
        .sheet(isPresented: $showTimePicker) {
            VStack(spacing: 20) {
                DatePicker(
                    "Wake Up Time",
                    selection: $tempWakeTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                
                Button("Set") {
                    let now = Date()
                    let calendar = Calendar.current
                    let components = calendar.dateComponents(
                        [.hour, .minute],
                        from: tempWakeTime
                    )
                    var wakeDate =
                    calendar.date(
                        bySettingHour: components.hour ?? 0,
                        minute: components.minute ?? 0,
                        second: 0,
                        of: now
                    ) ?? now
                    
                    if wakeDate <= now {
                        wakeDate =
                        calendar.date(
                            byAdding: .day,
                            value: 1,
                            to: wakeDate
                        ) ?? wakeDate
                    }
                    
                    let durationSeconds = wakeDate.timeIntervalSince(now)
                    durationMinutes = max(1, min(1440, durationSeconds / 60))  // Clamp to min 1 min, max 24 hours
                    
                    UserDefaults.standard.set(wakeDate, forKey: "lastWakeTime")  // Save the absolute wake date
                    
                    showTimePicker = false
                }
                .font(.headline)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showContentBrowser) {
            ContentBrowserView(
                storyManager: storyManager,
                poemManager: poemManager,
                isPresented: $showContentBrowser,
                onPlayStory: { storyText in
                    ttsManager.startSpeakingWithPauses(storyText)
                },
                onPlayPoem: { poemText in
                    ttsManager.startSpeakingWithPauses(poemText)
                }
            )
        }
        .sheet(isPresented: $showVoiceSettings, onDismiss: {
            // Refresh voice settings to ensure new voice selection takes effect immediately
            ttsManager.refreshVoiceSettings()
        }) {
            VoiceSettingsView(ttsManager: ttsManager)
        }
    }
    
    private func updateDurationToRemaining() {
        if let wakeDate = UserDefaults.standard.object(forKey: "lastWakeTime")
            as? Date
        {
            let now = Date()
            let remainingMinutes = wakeDate.timeIntervalSince(now) / 60
            if remainingMinutes > 0 {
                durationMinutes = min(1440, remainingMinutes)
            } else {
                // EXPIRED: Force infinite
                durationMinutes = 0
                UserDefaults.standard.set(0.0, forKey: "durationMinutes")
                UserDefaults.standard.removeObject(forKey: "lastWakeTime")
                UserDefaults.standard.removeObject(forKey: "selectedAlarmIndex")  // Clear sticky alarm
            }
        } else {
            // NO WAKE TIME: Ensure infinite
            durationMinutes = 0
            UserDefaults.standard.set(0.0, forKey: "durationMinutes")
        }
    }
}

