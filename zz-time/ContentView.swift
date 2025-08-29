import SwiftUI
import AVFoundation
import UIKit

// Extension to extract HSB components from Color
extension Color {
    var hsba: (hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s, b, a)
    }
}

struct SelectedItem: Identifiable, Equatable {
    let id: Int
}

struct BlobView: View {
    let i: Int
    let t: Double
    let baseHue: CGFloat
    let baseSaturation: CGFloat
    let baseBrightness: CGFloat
    
    private let numBlobs: Int = 15
    private let blobSize: CGFloat = 250
    private let blurRadius: CGFloat = 80
    private let amplitude: CGFloat = 200
    private let speed: Double = 0.75
    private let blobOpacity: Double = 0.6
    private let hueVariation: CGFloat = 0.1
    private let satVariation: CGFloat = 0.5
    private let brightVariation: CGFloat = 0.15
    private let brightBias: CGFloat = -0.15
    
    var body: some View {
        let phase = Double(i) * .pi * 2 / Double(numBlobs)
        let x = sin(t * speed + phase) * amplitude
        let y = cos(t * speed + phase * 1.3) * amplitude
        
        let hueOffset = sin(t * 0.1 + phase) * hueVariation
        let satOffset = cos(t * 0.15 + phase * 2) * satVariation
        let brightOffset = sin(t * 0.2 + phase * 3) * brightVariation + brightBias
        
        let variantColor = Color(
            hue: baseHue + hueOffset,
            saturation: max(0, min(1, baseSaturation + satOffset)),
            brightness: max(0.2, min(1, baseBrightness + brightOffset))
        )
        
        Circle()
            .fill(variantColor)
            .frame(width: blobSize, height: blobSize)
            .blur(radius: blurRadius)
            .offset(x: x, y: y)
            .opacity(blobOpacity)
            .blendMode(.overlay)
    }
}

struct BreathingBackground: View {
    let color: Color
    
    private let numBlobs: Int = 15
    
    var body: some View {
        let hsba = color.hsba
        let baseHue = hsba.hue
        let baseSaturation = hsba.saturation
        let baseBrightness = hsba.brightness
        
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince1970
            
            ZStack {
                color
                
                ForEach(0..<numBlobs) { i in
                    BlobView(
                        i: i,
                        t: t,
                        baseHue: baseHue,
                        baseSaturation: baseSaturation,
                        baseBrightness: baseBrightness
                    )
                }
            }
        }
    }
}

struct CustomSlider: UIViewRepresentable {
    @Binding var value: Double
    var minValue: Double = 0
    var maxValue: Double = 480
    var step: Double = 1
    var onEditingChanged: (Bool) -> Void = { _ in }
    
    private let exponent: Double = 2.0
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider()
        slider.minimumValue = 0.0
        slider.maximumValue = 1.0
        slider.minimumTrackTintColor = UIColor(white: 0.95, alpha: 1.0) // Very light grey
        slider.maximumTrackTintColor = UIColor(white: 0.95, alpha: 0.3) // Very light grey with opacity
        slider.setThumbImage(customThumbImage(), for: .normal)
        
        slider.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        slider.addTarget(context.coordinator, action: #selector(Coordinator.touchDown(_:)), for: [.touchDown])
        slider.addTarget(context.coordinator, action: #selector(Coordinator.touchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        return slider
    }
    
    func updateUIView(_ uiView: UISlider, context: Context) {
        let normalized = pow(value / maxValue, 1.0 / exponent)
        uiView.value = Float(normalized)
        uiView.setThumbImage(customThumbImage(), for: .normal)
    }
    
    private func customThumbImage() -> UIImage? {
        let size = CGSize(width: 34, height: 34)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let context = ctx.cgContext
            let circleRect = CGRect(origin: .zero, size: size).inset(by: UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2))
            context.setFillColor(UIColor(white: 0.7, alpha: 1.0).cgColor) // Softer gray
            context.addEllipse(in: circleRect)
            context.fillPath()
        }
    }
    
    class Coordinator {
        var parent: CustomSlider
        var isEditing = false
        
        init(parent: CustomSlider) {
            self.parent = parent
        }
        
        @objc func valueChanged(_ sender: UISlider) {
            let sliderValue = Double(sender.value)
            let raw: Double
            if sliderValue == 0.0 {
                raw = 0.0
            } else {
                raw = parent.maxValue * pow(sliderValue, parent.exponent)
            }
            let stepped = round(raw / parent.step) * parent.step
            parent.value = max(parent.minValue, min(parent.maxValue, stepped))
        }
        
        @objc func touchDown(_ sender: UISlider) {
            if !isEditing {
                isEditing = true
                parent.onEditingChanged(true)
            }
        }
        
        @objc func touchUp(_ sender: UISlider) {
            if isEditing {
                isEditing = false
                parent.onEditingChanged(false)
            }
        }
    }
}

enum DimMode {
    case duration(Double)
}

struct ExpandingView: View {
    let color: Color
    let dismiss: () -> Void
    @Binding var durationMinutes: Double
    @Binding var isAlarmActive: Bool // New binding to track alarm state
    
    @State private var showLabel: Bool = false
    @State private var dimOverlayOpacity: Double = 0.0
    @State private var flashOverlayOpacity: Double = 0.0
    @State private var dimMode: DimMode = .duration(360) // Default to 6 minutes
    
    var body: some View {
        ZStack {
            ZStack {
                BreathingBackground(color: color)
                    .ignoresSafeArea()
                
                Rectangle()
                    .fill(isAlarmActive ? Color(hue: 0.58, saturation: 0.3, brightness: 0.9) : .black)
                    .opacity(dimOverlayOpacity)
                    .ignoresSafeArea()
                
                Rectangle()
                    .fill(Color.white)
                    .opacity(flashOverlayOpacity)
                    .ignoresSafeArea()
            }
            
            VStack {
                CustomSlider(
                    value: $durationMinutes,
                    minValue: 0,
                    maxValue: 480,
                    step: 1,
                    onEditingChanged: { editing in
                        showLabel = editing
                    }
                )
                .padding(.horizontal, 40)
                
                if showLabel {
                    let text: String = {
                        if durationMinutes == 0 {
                            return "Infinite"
                        } else if durationMinutes < 60 {
                            let minutes = Int(durationMinutes)
                            return "\(minutes) Minute\(minutes == 1 ? "" : "s")"
                        } else {
                            let hours = Int(durationMinutes / 60)
                            let minutes = Int(durationMinutes.truncatingRemainder(dividingBy: 60))
                            if minutes == 0 {
                                return "\(hours) Hour\(hours == 1 ? "" : "s")"
                            } else {
                                return "\(hours) Hour\(hours == 1 ? "" : "s"), \(minutes) Minute\(minutes == 1 ? "" : "s")"
                            }
                        }
                    }()
                    
                    Text(text)
                        .font(.title)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                HStack(spacing: 40) {
                    Button {
                        print("Sun button tapped, triggering flash and setting dim duration to 360 seconds")
                        dimMode = .duration(360)
                        dimOverlayOpacity = 0
                        flashOverlayOpacity = 0.8 // Start with near-white flash
                        withAnimation(.linear(duration: 0.5)) {
                            flashOverlayOpacity = 0 // Rapidly fade out flash
                        }
                        withAnimation(.linear(duration: 360)) {
                            dimOverlayOpacity = 1 // Gradual fade to black
                        }
                    } label: {
                        Image(systemName: "sun.max.fill")
                            .font(.title)
                            .foregroundColor(Color(white: 0.7))
                            .padding(10)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .contentShape(Circle())
                    
                    Button {
                        print("Moon button tapped, setting dim duration to 4 seconds")
                        dimMode = .duration(4)
                        dimOverlayOpacity = 0
                        flashOverlayOpacity = 0 // Ensure flash is off
                        withAnimation(.linear(duration: 4)) {
                            dimOverlayOpacity = 1
                        }
                    } label: {
                        Image(systemName: "moon.fill")
                            .font(.title)
                            .foregroundColor(Color(white: 0.7))
                            .padding(10)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .contentShape(Circle())
                }
                .padding(.bottom, 40)
            }
        }
        .gesture(
            SimultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        print("Background tapped")
                        withAnimation(.easeInOut(duration: 0.3)) {
                            dismiss()
                        }
                    },
                DragGesture(minimumDistance: 20, coordinateSpace: .global)
                    .onEnded { value in
                        let translationHeight = value.translation.height
                        if translationHeight > 100 { // Detect downward swipe
                            print("Downward swipe detected")
                            withAnimation(.easeInOut(duration: 0.3)) {
                                dismiss()
                            }
                        }
                    }
            )
        )
        .onAppear {
            if case .duration(let seconds) = dimMode {
                print("ExpandingView appeared with dim duration: \(seconds) seconds")
                flashOverlayOpacity = 0 // Ensure flash is off on appear
                withAnimation(.linear(duration: seconds)) {
                    dimOverlayOpacity = 1
                }
            }
        }
        .onChange(of: isAlarmActive) { _, newValue in
            if newValue {
                // Start pulsing animation for alarm
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    dimOverlayOpacity = 0.8 // Pulse to soft light grayish-blue
                }
            } else {
                // Stop pulsing and revert to dimMode behavior
                withAnimation(.none) {
                    dimOverlayOpacity = 0 // Reset to avoid abrupt jump
                }
                if case .duration(let seconds) = dimMode {
                    withAnimation(.linear(duration: seconds)) {
                        dimOverlayOpacity = 1
                    }
                }
            }
        }
    }
}

struct ContentView: View {
    let files: [String] = (1...21).map { String(format: "ambient-%02d", $0) } + Array(repeating: "", count: 7)
    
    private func colorFor(row: Int, col: Int) -> Color {
        let diag = CGFloat(row + col) / 8.0
        let startHue: CGFloat = 0.8
        let endHue: CGFloat = 0.33
        let hue = startHue - (startHue - endHue) * diag
        let saturation: CGFloat = 0.3
        let brightness: CGFloat = 0.9
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
    
    @Namespace private var animation: Namespace.ID
    @State private var selectedItem: SelectedItem? = nil
    @State private var currentPlayer: AVAudioPlayer? = nil
    @State private var currentTimer: Timer? = nil
    @State private var currentAudioFile: String? = nil
    @State private var durationMinutes: Double = UserDefaults.standard.double(forKey: "durationMinutes") // Initialize from UserDefaults
    @State private var stopTimer: Timer? = nil
    @State private var alarmPlayer: AVAudioPlayer? = nil
    @State private var alarmTimer: Timer? = nil
    @State private var hapticGenerator: UINotificationFeedbackGenerator? = nil
    @State private var isAlarmActive: Bool = false // New state to track alarm
    
    var body: some View {
        ZStack {
            Color.gray
                .ignoresSafeArea()
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(0..<25) { index in
                    let row = index / 5
                    let col = index % 5
                    let color = colorFor(row: row, col: col)
                    let file = index < files.count ? files[index] : ""
                    
                    Button(action: {
                        if !file.isEmpty {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedItem = SelectedItem(id: index)
                            }
                        }
                    }) {
                        Rectangle()
                            .fill(color)
                            .aspectRatio(1, contentMode: .fit)
                            .cornerRadius(8)
                    }
                    .matchedGeometryEffect(id: index, in: animation)
                    .opacity(selectedItem?.id == index ? 0 : 1)
                    .disabled(file.isEmpty)
                }
            }
            .padding(20)
            .disabled(selectedItem != nil)
            
            if let selected = selectedItem {
                let row = selected.id / 5
                let col = selected.id % 5
                let color = colorFor(row: row, col: col)
                
                ExpandingView(
                    color: color,
                    dismiss: {
                        selectedItem = nil
                        isAlarmActive = false // Reset alarm state on dismiss
                    },
                    durationMinutes: $durationMinutes,
                    isAlarmActive: $isAlarmActive
                )
                .matchedGeometryEffect(id: selected.id, in: animation)
            }
        }
        .onChange(of: selectedItem) { _, newValue in
            if let new = newValue {
                let file = files[new.id]
                if !file.isEmpty {
                    if let currFile = currentAudioFile, currFile == file {
                        currentTimer?.invalidate()
                        if let vol = currentPlayer?.volume, vol < 1.0 {
                            let remaining = 1.0 - Double(vol)
                            let fadeDuration = 2.0 * (remaining / 1.0)
                            let fadeSteps = 20
                            let stepDuration = fadeDuration / Double(fadeSteps)
                            let stepIncrement = Float(remaining) / Float(fadeSteps)
                            currentTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { _ in
                                if let currentVolume = self.currentPlayer?.volume, currentVolume < 1.0 {
                                    self.currentPlayer?.volume = min(1.0, currentVolume + stepIncrement)
                                } else {
                                    self.currentTimer?.invalidate()
                                    self.currentTimer = nil
                                }
                            }
                        }
                    } else {
                        fadeOutCurrent {
                            setupNewAudio(file: file)
                        }
                    }
                }
            } else {
                fadeOutCurrent()
                fadeOutAlarm()
                stopTimer?.invalidate()
                stopTimer = nil
                isAlarmActive = false // Reset alarm state
            }
        }
        .onChange(of: durationMinutes) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "durationMinutes") // Save to UserDefaults
            if let _ = selectedItem {
                stopTimer?.invalidate()
                stopTimer = nil
                if newValue > 0 {
                    let seconds = newValue * 60
                    stopTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in
                        self.fadeOutCurrent {
                            self.startAlarm()
                        }
                    }
                }
            }
        }
    }
    
    private func setupNewAudio(file: String) {
        guard let url = Bundle.main.url(forResource: file, withExtension: "mp3") else {
            print("Audio file not found: \(file).mp3")
            return
        }
        do {
            currentPlayer = try AVAudioPlayer(contentsOf: url)
            currentPlayer?.numberOfLoops = -1
            currentPlayer?.volume = 0.0
            currentPlayer?.play()
            currentAudioFile = file
            
            currentTimer?.invalidate()
            let fadeDuration: Double = 2.0
            let fadeSteps: Int = 20
            let stepDuration = fadeDuration / Double(fadeSteps)
            let stepIncrement = 1.0 / Float(fadeSteps)
            
            currentTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { _ in
                if let currentVolume = self.currentPlayer?.volume, currentVolume < 1.0 {
                    self.currentPlayer?.volume = min(1.0, currentVolume + stepIncrement)
                } else {
                    self.currentTimer?.invalidate()
                    self.currentTimer = nil
                }
            }
            
            if durationMinutes > 0 {
                let seconds = durationMinutes * 60
                stopTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in
                    self.fadeOutCurrent {
                        self.startAlarm()
                    }
                }
            }
        } catch {
            print("Error playing audio: \(error.localizedDescription)")
        }
    }
    
    private func fadeOutCurrent(completion: (() -> Void)? = nil) {
        if let player = currentPlayer, player.volume > 0.0 {
            currentTimer?.invalidate()
            let vol = player.volume
            let remaining = Double(vol)
            let fadeDuration = 2.0 * (remaining / 1.0)
            let fadeSteps = 20
            let stepDuration = fadeDuration / Double(fadeSteps)
            let stepDecrement = vol / Float(fadeSteps)
            
            currentTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { _ in
                if let currentVolume = self.currentPlayer?.volume, currentVolume > 0.0 {
                    self.currentPlayer?.volume = max(0.0, currentVolume - stepDecrement)
                } else {
                    self.currentTimer?.invalidate()
                    self.currentTimer = nil
                    self.currentPlayer?.stop()
                    self.currentPlayer = nil
                    self.currentAudioFile = nil
                    completion?()
                }
            }
        } else {
            currentPlayer?.stop()
            currentPlayer = nil
            currentAudioFile = nil
            completion?()
        }
    }
    
    private func startAlarm() {
        if alarmPlayer != nil {
            return // Already active
        }
        
        stopTimer?.invalidate()
        stopTimer = nil
        isAlarmActive = true // Set alarm state
        
        guard let url = Bundle.main.url(forResource: "alarm-01", withExtension: "mp3") else {
            print("Alarm audio file not found: alarm-01.mp3")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0.0
            player.play()
            self.alarmPlayer = player
            
            // Fade in quickly
            let fadeDuration: Double = 0.5
            let fadeSteps: Int = 10
            let stepDuration = fadeDuration / Double(fadeSteps)
            let stepIncrement = 1.0 / Float(fadeSteps)
            
            let fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
                if let currentVolume = self.alarmPlayer?.volume, currentVolume < 1.0 {
                    self.alarmPlayer?.volume = min(1.0, currentVolume + stepIncrement)
                } else {
                    timer.invalidate()
                }
            }
            
            // Haptic
            let haptic = UINotificationFeedbackGenerator()
            haptic.notificationOccurred(.warning)
            self.hapticGenerator = haptic
            
            // Repeat haptic every audio duration
            let interval = player.duration
            self.alarmTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                self.hapticGenerator?.notificationOccurred(.warning)
            }
        } catch {
            print("Error playing alarm: \(error.localizedDescription)")
        }
    }
    
    private func fadeOutAlarm(completion: (() -> Void)? = nil) {
        if let player = alarmPlayer, player.volume > 0.0 {
            alarmTimer?.invalidate()
            alarmTimer = nil
            hapticGenerator = nil
            isAlarmActive = false // Reset alarm state
            
            let vol = player.volume
            let remaining = Double(vol)
            let fadeDuration = 2.0 * (remaining / 1.0)
            let fadeSteps = 20
            let stepDuration = fadeDuration / Double(fadeSteps)
            let stepDecrement = vol / Float(fadeSteps)
            
            let fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
                if let currentVolume = self.alarmPlayer?.volume, currentVolume > 0.0 {
                    self.alarmPlayer?.volume = max(0.0, currentVolume - stepDecrement)
                } else {
                    timer.invalidate()
                    self.alarmPlayer?.stop()
                    self.alarmPlayer = nil
                    completion?()
                }
            }
        } else {
            alarmPlayer?.stop()
            alarmPlayer = nil
            alarmTimer?.invalidate()
            alarmTimer = nil
            hapticGenerator = nil
            isAlarmActive = false // Reset alarm state
            completion?()
        }
    }
}
