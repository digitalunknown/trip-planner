import SwiftUI
import QuickLook

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    
    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        private let url: URL
        
        init(url: URL) {
            self.url = url
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
