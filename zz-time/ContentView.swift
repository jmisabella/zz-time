import SwiftUI
import AVFoundation

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

struct SelectedItem: Identifiable, Equatable {
    let id: Int
}

// ExpandingView for the full-screen color (audio management moved to ContentView)
struct ExpandingView: View {
    let color: Color
    let dismiss: () -> Void
    
    var body: some View {
        color
            .ignoresSafeArea()
            .gesture(
                TapGesture()
                    .onEnded { _ in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            dismiss()
                        }
                    }
            )
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
                
                ExpandingView(color: color) {
                    selectedItem = nil
                }
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
//struct SelectedItem: Identifiable {
//    let id: Int
//}
//
//// ExpandingView for playing the looped audio with fade-in and background color
//struct ExpandingView: View {
//    let color: Color
//    let audioFile: String
//    let dismiss: () -> Void
//    
//    @State private var player: AVAudioPlayer? = nil
//    @State private var timer: Timer? = nil
//    
//    var body: some View {
//        color
//            .ignoresSafeArea()
//            .onAppear {
//                setupAudio()
//            }
//            .onDisappear {
//                player?.stop()
//                timer?.invalidate()
//                timer = nil
//            }
//            .gesture(
//                TapGesture()
//                    .onEnded { _ in
//                        withAnimation(.easeInOut(duration: 0.3)) {
//                            dismiss()
//                        }
//                    }
//            )
//    }
//    
//    private func setupAudio() {
//        guard let url = Bundle.main.url(forResource: audioFile, withExtension: "mp3") else {
//            print("Audio file not found: \(audioFile).mp3")
//            return
//        }
//        do {
//            player = try AVAudioPlayer(contentsOf: url)
//            player?.numberOfLoops = -1 // Infinite loop
//            player?.volume = 0.0 // Start at zero volume
//            player?.play()
//            
//            // Manual fade-in using a timer
//            let fadeDuration: Double = 2.0 // Adjust duration as needed
//            let fadeSteps: Int = 20 // Adjust for smoothness (higher = smoother)
//            let stepDuration = fadeDuration / Double(fadeSteps)
//            let stepIncrement = 1.0 / Float(fadeSteps)
//            
//            timer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { _ in
//                if let currentVolume = player?.volume, currentVolume < 1.0 {
//                    player?.volume = min(1.0, currentVolume + stepIncrement)
//                } else {
//                    timer?.invalidate()
//                    timer = nil
//                }
//            }
//        } catch {
//            print("Error playing audio: \(error.localizedDescription)")
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
//                let file = files[selected.id]
//                
//                ExpandingView(color: color, audioFile: file) {
//                    selectedItem = nil
//                }
//                .matchedGeometryEffect(id: selected.id, in: animation)
//            }
//        }
//    }
//}
