import SwiftUI
import UIKit

struct ReturnKeyTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    @Binding var isFirstResponder: Bool
    var autocapitalization: UITextAutocapitalizationType = .sentences
    var onReturn: () -> Void
    
    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.autocapitalizationType = autocapitalization
        tf.autocorrectionType = .default
        tf.clearButtonMode = .never
        tf.returnKeyType = .done
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator, action: #selector(Coordinator.textChanged), for: .editingChanged)
        return tf
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
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
    
    final class Coordinator: NSObject, UITextFieldDelegate {
        private let parent: ReturnKeyTextField
        
        init(_ parent: ReturnKeyTextField) {
            self.parent = parent
        }
        
        @objc func textChanged(_ textField: UITextField) {
            parent.text = textField.text ?? ""
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
    }
}

