import SwiftUI

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
