import SwiftUI
import AVFoundation
import UIKit  // Added for UIColor to extract HSB components

// Color extension for hex conversion (optional, not used now but kept for reference)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

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
    private let brightBias: CGFloat = -0.15  // Applied here (was unused originally)
    
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

// ExpandingView for the full-screen color with breathing effect (audio management moved to ContentView)
struct ExpandingView: View {
    let color: Color
    let dismiss: () -> Void
    @Binding var durationMinutes: Double
    
    @State private var showLabel: Bool = false
    
    var body: some View {
        ZStack {
            BreathingBackground(color: color)
                .ignoresSafeArea()
                .gesture(
                    TapGesture()
                        .onEnded { _ in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                dismiss()
                            }
                        }
                )
            
            VStack {
                Slider(value: $durationMinutes, in: 0...720, step: 1, onEditingChanged: { editing in
                    showLabel = editing
                })
                .accentColor(.white)
                .padding(.horizontal, 40)
                
                if showLabel {
                    let hours = Int(durationMinutes / 60)
                    let mins = Int(durationMinutes.truncatingRemainder(dividingBy: 60))
                    let text = durationMinutes == 0 ? "Infinite" : String(format: "%d:%02d", hours, mins)
                    Text(text)
                        .font(.title)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
        }
    }
}

// ContentView for the 5x5 grid
struct ContentView: View {
    // Array of audio filenames, updated to match "ambient-01", "ambient-02", etc.
    let files: [String] = (1...18).map { String(format: "ambient-%02d", $0) } + Array(repeating: "", count: 7)
    
    // Generate colors for the grid
    private func colorFor(row: Int, col: Int) -> Color {
        let diag = CGFloat(row + col) / 8.0
        let startHue: CGFloat = 0.8 // Pastel purple
        let endHue: CGFloat = 0.33 // Pastel green
        let hue = startHue - (startHue - endHue) * diag
        let saturation: CGFloat = 0.3 // Low for pastel
        let brightness: CGFloat = 0.9 // High for pastel
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
    
    @Namespace private var animation: Namespace.ID
    @State private var selectedItem: SelectedItem? = nil
    
    @State private var currentPlayer: AVAudioPlayer? = nil
    @State private var currentTimer: Timer? = nil
    @State private var currentAudioFile: String? = nil
    @State private var durationMinutes: Double = 0.0 // 0 means infinite
    @State private var stopTimer: Timer? = nil
    
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
                
                ExpandingView(color: color, dismiss: {
                    selectedItem = nil
                }, durationMinutes: $durationMinutes)
                .matchedGeometryEffect(id: selected.id, in: animation)
            }
        }
        .onChange(of: selectedItem) { _, newValue in
            if let new = newValue {
                let file = files[new.id]
                if !file.isEmpty {
                    if let currFile = currentAudioFile, currFile == file {
                        // Reverse fade-out to fade-in if needed
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
                stopTimer?.invalidate()
                stopTimer = nil
            }
        }
        .onChange(of: durationMinutes) { _, newValue in
            if let _ = selectedItem {
                stopTimer?.invalidate()
                stopTimer = nil
                if newValue > 0 {
                    let seconds = newValue * 60
                    stopTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in
                        self.fadeOutCurrent {
                            self.selectedItem = nil
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
            currentPlayer?.numberOfLoops = -1 // Infinite loop
            currentPlayer?.volume = 0.0 // Start at zero volume
            currentPlayer?.play()
            currentAudioFile = file
            
            // Manual fade-in using a timer
            currentTimer?.invalidate()
            let fadeDuration: Double = 2.0 // Adjust duration as needed
            let fadeSteps: Int = 20 // Adjust for smoothness (higher = smoother)
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
            
            // Schedule stop timer if duration is set
            if durationMinutes > 0 {
                let seconds = durationMinutes * 60
                stopTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in
                    self.fadeOutCurrent {
                        self.selectedItem = nil
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
}

//import SwiftUI
//import AVFoundation
//import UIKit  // Added for UIColor to extract HSB components
//
//// Color extension for hex conversion (optional, not used now but kept for reference)
//extension Color {
//    init(hex: String) {
//        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
//        var int: UInt64 = 0
//        Scanner(string: hex).scanHexInt64(&int)
//        let a, r, g, b: UInt64
//        switch hex.count {
//        case 3: // RGB (12-bit)
//            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
//        case 6: // RGB (24-bit)
//            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
//        case 8: // ARGB (32-bit)
//            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
//        default:
//            (a, r, g, b) = (1, 1, 1, 0)
//        }
//        self.init(
//            .sRGB,
//            red: Double(r) / 255,
//            green: Double(g) / 255,
//            blue:  Double(b) / 255,
//            opacity: Double(a) / 255
//        )
//    }
//}
//
//// Extension to extract HSB components from Color
//extension Color {
//    var hsba: (hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
//        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
//        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
//        return (h, s, b, a)
//    }
//}
//
//struct SelectedItem: Identifiable, Equatable {
//    let id: Int
//}
//
//struct BlobView: View {
//    let i: Int
//    let t: Double
//    let baseHue: CGFloat
//    let baseSaturation: CGFloat
//    let baseBrightness: CGFloat
//    
//    private let numBlobs: Int = 15
//    private let blobSize: CGFloat = 250
//    private let blurRadius: CGFloat = 80
//    private let amplitude: CGFloat = 200
//    private let speed: Double = 0.75
//    private let blobOpacity: Double = 0.6
//    private let hueVariation: CGFloat = 0.1
//    private let satVariation: CGFloat = 0.5
//    private let brightVariation: CGFloat = 0.15
//    private let brightBias: CGFloat = -0.15  // Applied here (was unused originally)
//    
//    var body: some View {
//        let phase = Double(i) * .pi * 2 / Double(numBlobs)
//        let x = sin(t * speed + phase) * amplitude
//        let y = cos(t * speed + phase * 1.3) * amplitude
//        
//        let hueOffset = sin(t * 0.1 + phase) * hueVariation
//        let satOffset = cos(t * 0.15 + phase * 2) * satVariation
//        let brightOffset = sin(t * 0.2 + phase * 3) * brightVariation + brightBias
//        
//        let variantColor = Color(
//            hue: baseHue + hueOffset,
//            saturation: max(0, min(1, baseSaturation + satOffset)),
//            brightness: max(0.2, min(1, baseBrightness + brightOffset))
//        )
//        
//        Circle()
//            .fill(variantColor)
//            .frame(width: blobSize, height: blobSize)
//            .blur(radius: blurRadius)
//            .offset(x: x, y: y)
//            .opacity(blobOpacity)
//            .blendMode(.overlay)
//    }
//}
//
//struct BreathingBackground: View {
//    let color: Color
//    
//    private let numBlobs: Int = 15
//    
//    var body: some View {
//        let hsba = color.hsba
//        let baseHue = hsba.hue
//        let baseSaturation = hsba.saturation
//        let baseBrightness = hsba.brightness
//        
//        TimelineView(.animation) { context in
//            let t = context.date.timeIntervalSince1970
//            
//            ZStack {
//                color
//                
//                ForEach(0..<numBlobs) { i in
//                    BlobView(
//                        i: i,
//                        t: t,
//                        baseHue: baseHue,
//                        baseSaturation: baseSaturation,
//                        baseBrightness: baseBrightness
//                    )
//                }
//            }
//        }
//    }
//}
//
//// ExpandingView for the full-screen color with breathing effect (audio management moved to ContentView)
//struct ExpandingView: View {
//    let color: Color
//    let dismiss: () -> Void
//    @Binding var durationMinutes: Double
//    
//    @State private var showLabel: Bool = false
//    
//    var body: some View {
//        ZStack {
//            BreathingBackground(color: color)
//                .ignoresSafeArea()
//                .gesture(
//                    TapGesture()
//                        .onEnded { _ in
//                            withAnimation(.easeInOut(duration: 0.3)) {
//                                dismiss()
//                            }
//                        }
//                )
//            
//            VStack {
//                if showLabel {
//                    let hours = Int(durationMinutes / 60)
//                    let mins = Int(durationMinutes.truncatingRemainder(dividingBy: 60))
//                    let text = durationMinutes == 0 ? "Infinite" : String(format: "%d:%02d", hours, mins)
//                    Text(text)
//                        .font(.title)
//                        .foregroundColor(.white)
//                        .padding()
//                        .background(Color.black.opacity(0.5))
//                        .cornerRadius(8)
//                }
//                Slider(value: $durationMinutes, in: 0...720, step: 1, onEditingChanged: { editing in
//                    showLabel = editing
//                })
//                .accentColor(.white)
//                .padding(.horizontal, 40)
//                Spacer()
//            }
//        }
//    }
//}
//
//// ContentView for the 5x5 grid
//struct ContentView: View {
//    // Array of audio filenames, updated to match "ambient-01", "ambient-02", etc.
//    let files: [String] = (1...18).map { String(format: "ambient-%02d", $0) } + Array(repeating: "", count: 7)
//    
//    // Generate colors for the grid
//    private func colorFor(row: Int, col: Int) -> Color {
//        let diag = CGFloat(row + col) / 8.0
//        let startHue: CGFloat = 0.8 // Pastel purple
//        let endHue: CGFloat = 0.33 // Pastel green
//        let hue = startHue - (startHue - endHue) * diag
//        let saturation: CGFloat = 0.3 // Low for pastel
//        let brightness: CGFloat = 0.9 // High for pastel
//        return Color(hue: hue, saturation: saturation, brightness: brightness)
//    }
//    
//    @Namespace private var animation: Namespace.ID
//    @State private var selectedItem: SelectedItem? = nil
//    
//    @State private var currentPlayer: AVAudioPlayer? = nil
//    @State private var currentTimer: Timer? = nil
//    @State private var currentAudioFile: String? = nil
//    @State private var durationMinutes: Double = 0.0 // 0 means infinite
//    @State private var stopTimer: Timer? = nil
//    
//    var body: some View {
//        ZStack {
//            Color.gray
//                .ignoresSafeArea()
//            
//            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
//                ForEach(0..<25) { index in
//                    let row = index / 5
//                    let col = index % 5
//                    let color = colorFor(row: row, col: col)
//                    let file = index < files.count ? files[index] : ""
//                    
//                    Button(action: {
//                        if !file.isEmpty {
//                            withAnimation(.easeInOut(duration: 0.3)) {
//                                selectedItem = SelectedItem(id: index)
//                            }
//                        }
//                    }) {
//                        Rectangle()
//                            .fill(color)
//                            .aspectRatio(1, contentMode: .fit)
//                            .cornerRadius(8)
//                    }
//                    .matchedGeometryEffect(id: index, in: animation)
//                    .opacity(selectedItem?.id == index ? 0 : 1)
//                    .disabled(file.isEmpty)
//                }
//            }
//            .padding(20)
//            .disabled(selectedItem != nil)
//            
//            if let selected = selectedItem {
//                let row = selected.id / 5
//                let col = selected.id % 5
//                let color = colorFor(row: row, col: col)
//                
//                ExpandingView(color: color, dismiss: {
//                    selectedItem = nil
//                }, durationMinutes: $durationMinutes)
//                .matchedGeometryEffect(id: selected.id, in: animation)
//            }
//        }
//        .onChange(of: selectedItem) { _, newValue in
//            if let new = newValue {
//                let file = files[new.id]
//                if !file.isEmpty {
//                    if let currFile = currentAudioFile, currFile == file {
//                        // Reverse fade-out to fade-in if needed
//                        currentTimer?.invalidate()
//                        if let vol = currentPlayer?.volume, vol < 1.0 {
//                            let remaining = 1.0 - Double(vol)
//                            let fadeDuration = 2.0 * (remaining / 1.0)
//                            let fadeSteps = 20
//                            let stepDuration = fadeDuration / Double(fadeSteps)
//                            let stepIncrement = Float(remaining) / Float(fadeSteps)
//                            currentTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { _ in
//                                if let currentVolume = self.currentPlayer?.volume, currentVolume < 1.0 {
//                                    self.currentPlayer?.volume = min(1.0, currentVolume + stepIncrement)
//                                } else {
//                                    self.currentTimer?.invalidate()
//                                    self.currentTimer = nil
//                                }
//                            }
//                        }
//                    } else {
//                        fadeOutCurrent {
//                            setupNewAudio(file: file)
//                        }
//                    }
//                }
//            } else {
//                fadeOutCurrent()
//                stopTimer?.invalidate()
//                stopTimer = nil
//            }
//        }
//        .onChange(of: durationMinutes) { _, newValue in
//            if let _ = selectedItem {
//                stopTimer?.invalidate()
//                stopTimer = nil
//                if newValue > 0 {
//                    let seconds = newValue * 60
//                    stopTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in
//                        self.fadeOutCurrent {
//                            self.selectedItem = nil
//                        }
//                    }
//                }
//            }
//        }
//    }
//    
//    private func setupNewAudio(file: String) {
//        guard let url = Bundle.main.url(forResource: file, withExtension: "mp3") else {
//            print("Audio file not found: \(file).mp3")
//            return
//        }
//        do {
//            currentPlayer = try AVAudioPlayer(contentsOf: url)
//            currentPlayer?.numberOfLoops = -1 // Infinite loop
//            currentPlayer?.volume = 0.0 // Start at zero volume
//            currentPlayer?.play()
//            currentAudioFile = file
//            
//            // Manual fade-in using a timer
//            currentTimer?.invalidate()
//            let fadeDuration: Double = 2.0 // Adjust duration as needed
//            let fadeSteps: Int = 20 // Adjust for smoothness (higher = smoother)
//            let stepDuration = fadeDuration / Double(fadeSteps)
//            let stepIncrement = 1.0 / Float(fadeSteps)
//            
//            currentTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { _ in
//                if let currentVolume = self.currentPlayer?.volume, currentVolume < 1.0 {
//                    self.currentPlayer?.volume = min(1.0, currentVolume + stepIncrement)
//                } else {
//                    self.currentTimer?.invalidate()
//                    self.currentTimer = nil
//                }
//            }
//            
//            // Schedule stop timer if duration is set
//            if durationMinutes > 0 {
//                let seconds = durationMinutes * 60
//                stopTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in
//                    self.fadeOutCurrent {
//                        self.selectedItem = nil
//                    }
//                }
//            }
//        } catch {
//            print("Error playing audio: \(error.localizedDescription)")
//        }
//    }
//    
//    private func fadeOutCurrent(completion: (() -> Void)? = nil) {
//        if let player = currentPlayer, player.volume > 0.0 {
//            currentTimer?.invalidate()
//            let vol = player.volume
//            let remaining = Double(vol)
//            let fadeDuration = 2.0 * (remaining / 1.0)
//            let fadeSteps = 20
//            let stepDuration = fadeDuration / Double(fadeSteps)
//            let stepDecrement = vol / Float(fadeSteps)
//            
//            currentTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { _ in
//                if let currentVolume = self.currentPlayer?.volume, currentVolume > 0.0 {
//                    self.currentPlayer?.volume = max(0.0, currentVolume - stepDecrement)
//                } else {
//                    self.currentTimer?.invalidate()
//                    self.currentTimer = nil
//                    self.currentPlayer?.stop()
//                    self.currentPlayer = nil
//                    self.currentAudioFile = nil
//                    completion?()
//                }
//            }
//        } else {
//            currentPlayer?.stop()
//            currentPlayer = nil
//            currentAudioFile = nil
//            completion?()
//        }
//    }
//}
