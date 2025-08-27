import SwiftUI
import AVFoundation

// Color extension for hex conversion
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

struct SelectedItem: Identifiable {
    let id: Int
}

// ContentView for the 5x5 grid
struct ContentView: View {
    // Array of audio filenames. Replace "ambient1" etc. with your actual filenames (without extension, assuming .mp3).
    // Add the mp3 files to your Xcode project (drag them into the project navigator, check "Copy if needed").
   
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
    
    @State private var selectedItem: SelectedItem? = nil
    
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
                            selectedItem = SelectedItem(id: index)
                        }
                    }) {
                        Rectangle()
                            .fill(color)
                            .aspectRatio(1, contentMode: .fit)
                            .cornerRadius(8)
                    }
                    .disabled(file.isEmpty)
                }
            }
            .padding(20)
        }
        .fullScreenCover(item: $selectedItem) { item in
            let index = item.id
            let row = index / 5
            let col = index % 5
            let color = colorFor(row: row, col: col)
            let hex = hexStringFrom(color: color)
            let file = files[index]
            AudioView(colorHex: hex, audioFile: file)
        }
    }
}

// Helper to get hex from Color (if needed, but since we can pass Color directly, optional)
func hexStringFrom(color: Color) -> String {
    let uiColor = UIColor(color)
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
    let rgb: Int = (Int)(r * 255) << 16 | (Int)(g * 255) << 8 | (Int)(b * 255) << 0
    return String(format: "#%06x", rgb)
}

// AudioView for playing the looped audio with fade-in and background color
struct AudioView: View {
    let colorHex: String
    let audioFile: String
    
    @State private var player: AVAudioPlayer? = nil
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Color(hex: colorHex)
            .ignoresSafeArea()
            .onAppear {
                setupAudio()
            }
            .onDisappear {
                player?.stop()
            }
            .gesture(
                TapGesture()
                    .onEnded { _ in
                        dismiss()
                    }
            )
    }
    
    private func setupAudio() {
            guard let url = Bundle.main.url(forResource: audioFile, withExtension: "mp3") else {
                print("Audio file not found: \(audioFile).mp3")
                return
            }
            do {
                player = try AVAudioPlayer(contentsOf: url)
                player?.numberOfLoops = -1 // Infinite loop
                player?.volume = 0.0 // Start at zero volume
                player?.play()
                // Fade in over 2 seconds (adjust duration as needed)
                withAnimation(.linear(duration: 2.0)) {
                    player?.volume = 1.0
                }
            } catch {
                print("Error playing audio: \(error.localizedDescription)")
            }
        }
    }

