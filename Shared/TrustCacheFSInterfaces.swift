import Foundation

@objc public extension UserDefaults {
    var appRegistrarTestModeEnabled: Bool { bool(forKey: "TestMode") }
}

extension String {
    static let appRegistrarRequestsPath: String = {
        if UserDefaults.standard.appRegistrarTestModeEnabled {
            try! FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appending(path: "AppRegistrarTests", directoryHint: .isDirectory)
                .appending(path: "TrustCacheRequests", directoryHint: .isDirectory)
                .path
        } else {
            "/private/var/installd/Library/Caches/TrustCacheRequests"
        }
    }()
}

/// Whether the debug file is present, meaning certain debugging features should be enabled.
func TrustCacheDebuggingEnabled() -> Bool {
    FileManager.default.fileExists(atPath: String.appRegistrarRequestsPath + "/" + TrustCacheFSConstants.debugFolderName)
}

@objc public final class TrustCacheFSConstants: NSObject {
    static let requestFileExtension = "plist"

    /// When the daemon fails to fulfill a request, it writes an error message to a plain text file
    /// with the request ID and this extension.
    static let errorFileExtension = "error"

    /// The directory where trust cache requests are placed by `installd` and observed by `appregistrard`.
    @objc public static let requestsDirectoryURL = URL(filePath: "\(String.appRegistrarRequestsPath)", directoryHint: .isDirectory)

    /// A folder that can be placed in `appRegistrarRequestsPath` to enable certain debugging features.
    static let debugFolderName = "_debug"
}

@objc public enum TrustCacheFSRequestAction: Int32, Codable {
    case load
    case fullChain
}

@objc public final class TrustCacheFSRequest: NSObject, Codable, NSFilePresenter {
    enum CodingKeys: String, CodingKey {
        case id, action, bundleURL, requestURL
    }
    
    @objc public private(set) var id: UUID
    @objc public private(set) var action: TrustCacheFSRequestAction
    @objc public private(set) var bundleURL: URL

    /// If ``action`` is ``TrustCacheFSRequestAction/load``, the path to the trust cache img4 file.
    @objc public private(set) var trustCacheURL: URL? = nil

    /// Not exposed to objc because this is only used in `appregistrard`.
    private(set) var requestURL: URL
    private var _coordinator: NSFileCoordinator!
    var coordinator: NSFileCoordinator { _coordinator }
    public var presentedItemURL: URL? { requestURL }
    public var presentedItemOperationQueue: OperationQueue = .main

    private(set) lazy var errorURL = requestURL.deletingPathExtension().appendingPathExtension(TrustCacheFSConstants.errorFileExtension)

    @objc public init(action: TrustCacheFSRequestAction, bundleURL: URL, trustCacheURL: URL? = nil) {
        self.id = UUID()
        self.action = action
        self.bundleURL = bundleURL
        self.trustCacheURL = trustCacheURL
        self.requestURL = TrustCacheFSConstants.requestsDirectoryURL
            .appendingPathComponent(id.uuidString)
            .appendingPathExtension(TrustCacheFSConstants.requestFileExtension)

        super.init()

        self._coordinator = NSFileCoordinator(filePresenter: self)
    }

    public override var description: String {
        switch action {
        case .load: "<\(id.shortID) LOAD \"\(trustCacheURL?.path ?? "<nil>")\">"
        case .fullChain:  "<\(id.shortID) FULL \"\(bundleURL.path)\">"
        }
    }
}

extension UUID {
    var shortID: String { uuidString.components(separatedBy: "-").first ?? uuidString }
}
