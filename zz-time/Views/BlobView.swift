import SwiftUI

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
