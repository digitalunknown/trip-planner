import SwiftUI
import UIKit

struct ReturnKeyTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    @Binding var isFirstResponder: Bool
    var autocapitalization: UITextAutocapitalizationType = .sentences
    var maxLength: Int? = nil
    var onReturn: () -> Void
    
    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.autocapitalizationType = autocapitalization
        tf.autocorrectionType = .default
        tf.clearButtonMode = .never
        tf.returnKeyType = .done
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator, action: #selector(Coordinator.textChanged), for: .editingChanged)
        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        applyTypography(tf)
        return tf
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        applyTypography(uiView)
        if uiView.text != text {
            uiView.text = text
        }
        
        if isFirstResponder, !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFirstResponder, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func applyTypography(_ textField: UITextField) {
        let font = AppFont.uiFont(size: 15, weight: .medium)
        textField.font = font
        textField.textColor = UIColor(AppColor.textStrong)
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .font: font,
                .foregroundColor: UIColor(AppColor.textWeak)
            ]
        )
    }
    
    final class Coordinator: NSObject, UITextFieldDelegate {
        private let parent: ReturnKeyTextField
        
        init(_ parent: ReturnKeyTextField) {
            self.parent = parent
        }
        
        @objc func textChanged(_ textField: UITextField) {
            let value = textField.text ?? ""
            if let maxLength = parent.maxLength, value.count > maxLength {
                let clipped = String(value.prefix(maxLength))
                textField.text = clipped
                parent.text = clipped
            } else {
                parent.text = value
            }
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.isFirstResponder = true
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.isFirstResponder = false
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onReturn()
            return false
        }
        
        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            guard let maxLength = parent.maxLength else { return true }
            let current = textField.text ?? ""
            guard let swiftRange = Range(range, in: current) else { return true }
            let next = current.replacingCharacters(in: swiftRange, with: string)
            return next.count <= maxLength
        }
    }
}

