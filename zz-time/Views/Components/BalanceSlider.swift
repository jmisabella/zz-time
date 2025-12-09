import SwiftUI
import UIKit

struct BalanceSlider: UIViewRepresentable {
    @Binding var value: Double  // Range from 0.0 (0% ambient) to 1.0 (100% ambient)
    var onEditingChanged: (Bool) -> Void = { _ in }

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
        uiView.value = Float(value)
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
        var parent: BalanceSlider
        var isEditing = false
        
        init(parent: BalanceSlider) {
            self.parent = parent
        }
        
        @objc func valueChanged(_ sender: UISlider) {
            parent.value = Double(sender.value)
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
