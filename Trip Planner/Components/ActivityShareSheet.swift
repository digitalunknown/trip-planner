import SwiftUI
import UIKit

/// File-URL based share sheet (preferred over passing `UIImage` directly).
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.excludedActivityTypes = excludedActivityTypes
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum StatsShareExporter {
    @MainActor
    static func pngFileURL<Content: View>(
        for content: Content,
        scale: CGFloat = 3,
        filenamePrefix: String = "tripstacks-stamp"
    ) -> URL? {
        let renderer = ImageRenderer(content: content)
        renderer.scale = scale
        guard let image = renderer.uiImage, let data = image.pngData() else { return nil }
        
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(filenamePrefix)-\(UUID().uuidString).png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
