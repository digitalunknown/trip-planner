import Foundation
import UniformTypeIdentifiers

enum ActivityDocumentStore {
    private static let rootFolderName = "ActivityDocuments"
    
    private static var rootDirectoryURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(rootFolderName, isDirectory: true)
    }
    
    @discardableResult
    private static func ensureRootDirectoryExists() throws -> URL {
        let root = rootDirectoryURL
        if !FileManager.default.fileExists(atPath: root.path(percentEncoded: false)) {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }
        return root
    }
    
    static func fileURL(for relativePath: String) -> URL {
        rootDirectoryURL.appendingPathComponent(relativePath, isDirectory: false)
    }
    
    static func saveImportedFile(
        from sourceURL: URL,
        source: EventDocumentSource = .files
    ) throws -> EventDocument {
        _ = try ensureRootDirectoryExists()
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        
        let originalFileName = sourceURL.lastPathComponent
        let originalExt = sourceURL.pathExtension.lowercased()
        let extensionOrFallback = originalExt.isEmpty ? "bin" : originalExt
        let storedName = "\(UUID().uuidString).\(extensionOrFallback)"
        let relativePath = storedName
        let destinationURL = fileURL(for: relativePath)
        
        if FileManager.default.fileExists(atPath: destinationURL.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        
        let type = UTType(filenameExtension: extensionOrFallback)
        
        return EventDocument(
            fileName: originalFileName,
            fileExtension: extensionOrFallback,
            mimeType: type?.preferredMIMEType,
            localRelativePath: relativePath,
            source: source
        )
    }
    
    static func saveImageData(
        _ data: Data,
        source: EventDocumentSource = .photoLibrary,
        preferredFileName: String = "Photo.jpg"
    ) throws -> EventDocument {
        _ = try ensureRootDirectoryExists()
        let ext = (preferredFileName as NSString).pathExtension.lowercased().isEmpty ? "jpg" : (preferredFileName as NSString).pathExtension.lowercased()
        let storedName = "\(UUID().uuidString).\(ext)"
        let relativePath = storedName
        let url = fileURL(for: relativePath)
        try data.write(to: url, options: .atomic)
        
        return EventDocument(
            fileName: preferredFileName,
            fileExtension: ext,
            mimeType: UTType(filenameExtension: ext)?.preferredMIMEType,
            localRelativePath: relativePath,
            source: source,
            thumbnailData: data
        )
    }
    
    static func delete(document: EventDocument) {
        delete(relativePath: document.localRelativePath)
    }
    
    static func delete(relativePath: String) {
        let url = fileURL(for: relativePath)
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        try? FileManager.default.removeItem(at: url)
    }
    
    static func delete(documents: [EventDocument]) {
        for doc in documents {
            delete(document: doc)
        }
    }
    
    static func referencedRelativePaths(in trips: [Trip]) -> Set<String> {
        var paths = Set<String>()
        for trip in trips {
            for idea in trip.parkedIdeas {
                idea.documents.forEach { paths.insert($0.localRelativePath) }
            }
            for day in trip.days {
                for event in day.events {
                    event.documents.forEach { paths.insert($0.localRelativePath) }
                }
                for flight in day.flights {
                    flight.documents.forEach { paths.insert($0.localRelativePath) }
                }
            }
        }
        return paths
    }
    
    static func pruneUnreferencedFiles(in trips: [Trip]) {
        let referenced = referencedRelativePaths(in: trips)
        pruneUnreferencedFiles(referencedRelativePaths: referenced)
    }
    
    static func pruneUnreferencedFiles(referencedRelativePaths: Set<String>) {
        let root = rootDirectoryURL
        guard FileManager.default.fileExists(atPath: root.path(percentEncoded: false)) else { return }
        let children = (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        for fileURL in children {
            let relative = fileURL.lastPathComponent
            if !referencedRelativePaths.contains(relative) {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
}
