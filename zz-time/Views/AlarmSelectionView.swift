import SwiftUI
import AVFoundation

struct AlarmSelectionView: View {
    @Binding var selectedAlarmIndex: Int?
    let files: [String]
    let fadeMainTo: (Float) -> Void
    
    @State private var previewPlayer: AVAudioPlayer? = nil
    @State private var previewTimer: Timer? = nil
    @Environment(\.dismiss) private var dismiss
    
    private func alarmColorFor(row: Int, col: Int, isSelected: Bool) -> Color {
        let origRow = row
        let diag = CGFloat(origRow + col) / 8.0
        let startHue: CGFloat = 0.166 // Yellow
        var endHue: CGFloat = 0.916 // Pink
        var delta = endHue - startHue
        if abs(delta) > 0.5 {
            delta -= (delta > 0 ? 1.0 : -1.0)
        }
        var hue = startHue + delta * diag
        if hue < 0 {
            hue += 1
        } else if hue > 1 {
            hue -= 1
        }
        let saturation: CGFloat = 0.8
        let brightness: CGFloat = 0.9
        return Color(hue: hue, saturation: saturation, brightness: isSelected ? brightness : brightness * 0.5)
    }
    
    var body: some View {
        ZStack {
            Color(white: 0.1) // Near-black background
                .ignoresSafeArea()
            
            GeometryReader { geo in
                let spacing: CGFloat = 10
                let padding: CGFloat = 20
                let availW = geo.size.width - 2 * padding
                let availH = geo.size.height - 2 * padding
                let numCols: CGFloat = 5
                let numRows: CGFloat = 5
                let itemW = (availW - spacing * (numCols - 1)) / numCols
                let itemH = (availH - spacing * (numRows - 1)) / numRows
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: 5), spacing: spacing) {
                    ForEach(5..<30) { index in
                        let row = (index - 5) / 5
                        let col = (index - 5) % 5
                        let isSelected = selectedAlarmIndex == index
                        let color = alarmColorFor(row: row, col: col, isSelected: isSelected)
                        
                        Rectangle()
                            .fill(color)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                isSelected ?
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white, lineWidth: 4)
                                    : nil
                            )
                            .cornerRadius(8)
                            .onTapGesture {
                                if isSelected {
                                    selectedAlarmIndex = nil
                                } else {
                                    selectedAlarmIndex = index
                                }
                                playPreview(for: index)
                            }
                    }
                }
                .padding(padding)
            }
        }
        .onAppear {
            fadeMainTo(0.2)
        }
        .onDisappear {
            fadeOutPreview()
            fadeMainTo(1.0)
        }
    }
    
    private func playPreview(for index: Int) {
        let file = files[index]
        guard let url = Bundle.main.url(forResource: file, withExtension: "mp3") else {
            print("Preview file not found: \(file).mp3")
            return
        }
        fadeOutPreview {
            do {
                previewPlayer = try AVAudioPlayer(contentsOf: url)
                previewPlayer?.numberOfLoops = 0 // Play once for preview
                previewPlayer?.volume = 0.0
                previewPlayer?.play()
                
                let fadeDuration: Double = 1.0 // Shorter fade for preview
                let fadeSteps: Int = 10
                let stepDuration = fadeDuration / Double(fadeSteps)
                let stepIncrement = 0.5 / Float(fadeSteps) // Fade to 0.5 volume for preview
                
                previewTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { _ in
                    if let currentVolume = self.previewPlayer?.volume, currentVolume < 0.5 {
                        self.previewPlayer?.volume = min(0.5, currentVolume + stepIncrement)
                    } else {
                        self.previewTimer?.invalidate()
                        self.previewTimer = nil
                    }
                }
            } catch {
                print("Error playing preview: \(error.localizedDescription)")
            }
        }
    }
    
    private func fadeOutPreview(completion: (() -> Void)? = nil) {
        if let player = previewPlayer, player.volume > 0.0 {
            previewTimer?.invalidate()
            let vol = player.volume
            let fadeDuration = 1.0
            let fadeSteps = 10
            let stepDuration = fadeDuration / Double(fadeSteps)
            let stepDecrement = vol / Float(fadeSteps)
            
            previewTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { _ in
                if let currentVolume = self.previewPlayer?.volume, currentVolume > 0.0 {
                    self.previewPlayer?.volume = max(0.0, currentVolume - stepDecrement)
                } else {
                    self.previewTimer?.invalidate()
                    self.previewTimer = nil
                    self.previewPlayer?.stop()
                    self.previewPlayer = nil
                    completion?()
                }
            }
        } else {
            previewPlayer?.stop()
            previewPlayer = nil
            completion?()
        }
    }
}

struct AlarmItemView: View {
    let index: Int
    let aspect: CGFloat
    let colorFor: (Int, Int) -> Color
    let files: [String]
    let selectedItem: SelectedItem?
    let animation: Namespace.ID
    let onSelect: (Int) -> Void
    
    var body: some View {
        let row = index / 5
        let col = index % 5
        let color = colorFor(row, col)
        let file = index < files.count ? files[index] : ""
        
        Button(action: {
            if !file.isEmpty {
                onSelect(index)
            }
        }) {
            Rectangle()
                .fill(color)
                .aspectRatio(aspect, contentMode: .fit)
                .cornerRadius(8)
        }
        .matchedGeometryEffect(id: index, in: animation)
        .opacity(selectedItem?.id == index ? 0 : 1)
        .disabled(file.isEmpty)
    }
}
