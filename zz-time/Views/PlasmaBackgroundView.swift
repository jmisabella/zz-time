import SwiftUI

struct PlasmaBackground: View {
    let color: Color
    
    var body: some View {
        let hsba = color.hsba
        let baseHue = hsba.hue
        let baseSaturation = hsba.saturation
        let baseBrightness = hsba.brightness
        
        // Derive a 2-3 color palette from the base color
        let color1 = Color(hue: baseHue, saturation: baseSaturation * 0.95, brightness: min(1, baseBrightness * 1.05))
        let color2 = Color(hue: (baseHue + 0.1).truncatingRemainder(dividingBy: 1), saturation: min(1, baseSaturation * 1.05), brightness: baseBrightness * 0.95)
        let color3 = Color(hue: (baseHue - CGFloat(0.1) + CGFloat(1)).truncatingRemainder(dividingBy: 1), saturation: baseSaturation * 0.9, brightness: min(1, baseBrightness * 1.1))
        
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSince1970 * 0.1
            
            GeometryReader { geo in
                Canvas { context, size in
                    let width = size.width
                    let height = size.height
                    
                    // Create a grid of points to compute the plasma effect
                    for x in stride(from: 0, to: width, by: 4) {
                        for y in stride(from: 0, to: height, by: 4) {
                            let uvX = x / width
                            let uvY = y / height
                            
                            // Plasma effect calculation (matching Android's PLASMA_SHADER)
                            var v: CGFloat = 0
                            v += sin((uvX * 8.0) + time)
                            v += sin((uvY * 8.0) + time * 0.7)
                            v += sin((uvX + uvY) * 4.0 + time * 0.4)
                            v += sin(sqrt(uvX * uvX + uvY * uvY) * 12.0 + time * 0.3)
                            v /= 4.0
                            v = sin(v * CGFloat.pi) * 0.5 + 0.5
                            
                            // Interpolate between colors based on v
                            let col: Color
                            if v < 0.5 {
                                col = Color.blend(color1, color2, ratio: v * 2.0)
                            } else {
                                col = Color.blend(color2, color3, ratio: (v - 0.5) * 2.0)
                            }
                            
                            // Draw a small rectangle at each point
                            let rect = CGRect(x: x, y: y, width: 4, height: 4)
                            context.fill(Path(rect), with: .color(col))
                        }
                    }
                }
            }
            .ignoresSafeArea()
        }
    }
}

