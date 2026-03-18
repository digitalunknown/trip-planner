import Foundation

final class ICloudFilePresenter: NSObject, NSFilePresenter {
    let presentedItemURL: URL?
    let presentedItemOperationQueue: OperationQueue

    private let onChange: @MainActor () -> Void

    init(url: URL, onChange: @escaping @MainActor () -> Void) {
        self.presentedItemURL = url
        self.presentedItemOperationQueue = OperationQueue()
        self.presentedItemOperationQueue.maxConcurrentOperationCount = 1
        self.presentedItemOperationQueue.qualityOfService = .utility
        self.onChange = onChange
        super.init()
    }

    func presentedItemDidChange() {
        Task { @MainActor in
            onChange()
        }
    }
}

