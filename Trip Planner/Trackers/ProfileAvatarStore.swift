import Foundation
import UIKit

enum ProfileAvatarStore {
    private static let filename = "ProfileAvatar.jpg"
    
    private static var fileURL: URL {
        if let userID = CloudSyncPaths.currentAppleUserIdentifier() {
            return CloudSyncPaths.accountLocalRoot(for: userID).appendingPathComponent(filename)
        }
        return CloudSyncPaths.localAppSupportRoot()
            .appendingPathComponent("SignedOut", isDirectory: true)
            .appendingPathComponent(filename)
    }
    
    static func load() -> UIImage? {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }
    
    static func save(_ image: UIImage) {
        let url = fileURL
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: url, options: .atomic)
    }
    
    static func clear() {
        let url = fileURL
        try? FileManager.default.removeItem(at: url)
    }
}
