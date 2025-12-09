import SwiftUI
import UIKit

// Extension to extract HSB components from Color
extension Color {
    var hsba: (hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s, b, a)
    }
    
    static func blend(_ color1: Color, _ color2: Color, ratio: CGFloat) -> Color {
            let c1 = UIColor(color1)
            let c2 = UIColor(color2)

            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
            c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

            let r = r1 + (r2 - r1) * ratio
            let g = g1 + (g2 - g1) * ratio
            let b = b1 + (b2 - b1) * ratio
            let a = a1 + (a2 - a1) * ratio

            return Color(red: r, green: g, blue: b, opacity: a)
        }

    init(hex: Int, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, opacity: alpha)
    }
}
