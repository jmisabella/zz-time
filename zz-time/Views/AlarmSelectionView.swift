

// AlarmSelectionView.swift (new or updated file - assuming this is the structure based on context)
import SwiftUI
import AVFoundation

struct AlarmSelectionView: View {
    @Binding var selectedAlarmIndex: Int?
    let files: [String]
    
    @State private var previewPlayer: AVAudioPlayer? = nil
    @State private var previewTimer: Timer? = nil
    @Environment(\.dismiss) private var dismiss
    
    private func alarmColorFor(row: Int, col: Int) -> Color {
        if row == 0 {
            let hue: CGFloat = 0.67 // Blue hue, same as main
            let saturation: CGFloat = 0.6
            let diag = CGFloat(col) / 4.0
            let startBright: CGFloat = 0.6
            let endBright: CGFloat = 0.8
            let brightness = startBright + (endBright - startBright) * diag
            return Color(hue: hue, saturation: saturation, brightness: brightness)
        } else {
            let origRow = row - 1
            let diag = CGFloat(origRow + col) / 8.0
            let startHue: CGFloat = 0.083 // Orange
            let endHue: CGFloat = 0.916 // Pink
            let hue = startHue + (endHue - startHue) * diag
            let saturation: CGFloat = 0.8
            let brightness: CGFloat = 0.9
            return Color(hue: hue, saturation: saturation, brightness: brightness)
        }
    }
    
    var body: some View {
        ZStack {
            Color(white: 0.3) // Slightly dark grey background
                .ignoresSafeArea()
            
            GeometryReader { geo in
                let spacing: CGFloat = 10
                let padding: CGFloat = 20
                let availW = geo.size.width - 2 * padding
                let availH = geo.size.height - 2 * padding
                let numCols: CGFloat = 5
                let numRows: CGFloat = 6
                let itemW = (availW - spacing * (numCols - 1)) / numCols
                let maxItemH = (availH - spacing * (numRows - 1)) / numRows
                let itemH = min(itemW, maxItemH)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: 5), spacing: spacing) {
                    ForEach(0..<30) { index in
                        let row = index / 5
                        let col = index % 5
                        let color = alarmColorFor(row: row, col: col)
                        let isSelected = selectedAlarmIndex == index
                        
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
                .padding(20)
            }
            
            VStack {
                Spacer()
                Button("Done") {
                    fadeOutPreview {
                        dismiss()
                    }
                }
                .font(.title2)
                .foregroundColor(Color(white: 0.9)) // Off-white text
                .padding()
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)
                .padding(.bottom, 20)
            }
        }
        .onDisappear {
            fadeOutPreview()
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
    let onTap: (Int) -> Void
    
    var body: some View {
        let row = index / 5
        let col = index % 5
        let color = colorFor(row, col)
        let file = files[index]
        
        Rectangle()
            .fill(color)
            .aspectRatio(aspect, contentMode: .fit)
            .overlay(
                selectedItem?.id == index ?
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 4)
                    : nil
            )
            .cornerRadius(8)
            .opacity(file.isEmpty ? 0.5 : 1.0)
            .matchedGeometryEffect(id: index, in: animation)
            .onTapGesture {
                if !file.isEmpty {
                    onTap(index)
                }
            }
    }
}
