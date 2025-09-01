import SwiftUI
import UIKit

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
        slider.minimumTrackTintColor = UIColor(white: 0.95, alpha: 1.0)
        slider.maximumTrackTintColor = UIColor(white: 0.95, alpha: 0.3)
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
            context.setFillColor(UIColor(white: 0.7, alpha: 1.0).cgColor)
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
