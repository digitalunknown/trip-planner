import Foundation

enum CoordinatedFileIO {
    static func readData(from url: URL) throws -> Data {
        var data: Data?
        var coordinationError: NSError?
        var actionError: Error?

        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            do {
                data = try Data(contentsOf: coordinatedURL)
            } catch {
                actionError = error
            }
        }

        if let coordinationError { throw coordinationError }
        if let actionError { throw actionError }
        return data ?? Data()
    }

    static func writeData(_ data: Data, to url: URL) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var coordinationError: NSError?
        var actionError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(writingItemAt: url, options: [.forReplacing], error: &coordinationError) { coordinatedURL in
            do {
                try data.write(to: coordinatedURL, options: [.atomic])
            } catch {
                actionError = error
            }
        }
        if let coordinationError { throw coordinationError }
        if let actionError { throw actionError }
    }

    static func coordinatedCopyIfMissing(from src: URL, to dst: URL) throws {
        guard FileManager.default.fileExists(atPath: src.path) else { return }
        guard !FileManager.default.fileExists(atPath: dst.path) else { return }

        let dstDir = dst.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dstDir, withIntermediateDirectories: true)

        var coordinationError: NSError?
        var actionError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(writingItemAt: dst, options: [.forReplacing], error: &coordinationError) { coordinatedDst in
            do {
                try FileManager.default.copyItem(at: src, to: coordinatedDst)
            } catch let copyError {
                // If copy fails due to existing item race, ignore.
                if (copyError as NSError).code != NSFileWriteFileExistsError {
                    actionError = copyError
                }
            }
        }
        if let coordinationError { throw coordinationError }
        if let actionError { throw actionError }
    }
}

