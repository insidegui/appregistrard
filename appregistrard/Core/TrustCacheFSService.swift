/**
 # Filesystem-based communication

 In order to avoid having to replace installd with a custom build that allows it to communicate with an XPC service or using sandbox extension shenanigans,
 perform communication with `appregistrard` via the filesystem.

 This is needed because the list of daemons that `installd` can talk to is limited by its sandbox profile, so it can't talk to `appregistrard`.
 Doing the whole trust cache creation and loading also requires lots of entitlements that `installd` doesn't have, so doing it in process is not an option either.

 The daemon definitely has read and write access to `/var/installd/Library/Caches/com.apple.mobile.installd.staging`,
 but it's possible that it can access anything under `/var/installd/Library`.

 ## Architecture:

 - Upon receiving a request to validate the signature, `installd` (via `libAppRegistrarHooks`) writes a file describing the signing request
 - `appregistrard` observes the directory for these requests, and upon receiving one, creates and loads the trust cache
 - Once the trust cache has been successfully created and loaded `appregistrard` deletes the request file, which is the signal to `installd` that its work is done
 */

import Foundation
import OSLog

final class TrustCacheFSService: NSObject, NSFilePresenter {
    static let shared = TrustCacheFSService()
    
    private override init() {
        super.init()
    }

    private let logger = Logger(subsystem: kAppRegistrarSubsystem, category: String(describing: TrustCacheFSService.self))

    private var activated = false

    private lazy var coordinator: NSFileCoordinator = {
        NSFileCoordinator(filePresenter: self)
    }()

    func activate() {
        guard !activated else { return }
        activated = true

        logger.notice(#function)

        do {
            try TrustCacheFSRequest.createRequestsDirectoryIfNeeded()
        } catch {
            let dirName = TrustCacheFSConstants.requestsDirectoryURL.lastPathComponent
            logger.fault("Error creating \(dirName, privacy: .public) directory - \(error, privacy: .public)")
        }

        NSFileCoordinator.addFilePresenter(self)
    }

    // MARK: - Filesystem Operations

    let directoryURL = TrustCacheFSConstants.requestsDirectoryURL

    var presentedItemURL: URL? { directoryURL }

    var presentedItemOperationQueue: OperationQueue = .main

    func presentedItemDidChange() {
        logger.debug("\(#function, privacy: .public)")
    }

    func presentedSubitemDidAppear(at url: URL) {
        logger.debug("\(#function, privacy: .public) \(url.path, privacy: .public)")
    }

    func presentedSubitemDidChange(at url: URL) {
        logger.debug("\(#function, privacy: .public) \(url.path, privacy: .public)")

        guard url.pathExtension == TrustCacheFSConstants.requestFileExtension else { return }

        /// Ignore plists inside the `_debug` folder, which are just temporary debugging files and not meant to be processed.
        guard !url.path.contains(TrustCacheFSConstants.debugFolderName) else { return }

        /// We may get this callback when we ourselves delete the request file, so we can safely ignore requests for files that don't exist.
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let id = url.deletingPathExtension().lastPathComponent

        logger.notice("Received request \(id, privacy: .public)")

        var request: TrustCacheFSRequest? = nil
        do {
            var error: NSError?
            var outError: NSError?
            coordinator.coordinate(readingItemAt: url, error: &error) { coordinatedURL in
                do {
                    let data = try Data(contentsOf: coordinatedURL)
                    request = try PropertyListDecoder.trustCacheFS.decode(TrustCacheFSRequest.self, from: data)
                } catch let _error {
                    outError = _error as NSError
                }
            }

            if let error { throw error }
            if let outError { throw outError }
        } catch {
            logger.fault("Error reading request \(id, privacy: .public) - \(error, privacy: .public)")
            return
        }

        guard let request else {
            logger.fault("NO REQUEST!")
            return
        }

        do {
            logger.notice("Processing request \(request, privacy: .public)")

            switch request.action {
            case .load:
                try handleLoad(request)
            case .fullChain:
                try handleFullChain(request)
            }

            logger.notice("Successfully processed request \(request, privacy: .public)")

            do {
                try request.delete()

                logger.debug("Deleted request after successful execution - \(request, privacy: .public)")
            } catch {
                logger.fault("Error deleting request \(request.id, privacy: .public) after successful execution - \(error, privacy: .public)")
            }
        } catch {
            logger.error("Error fulfilling request \(id, privacy: .public) - \(error, privacy: .public)")

            request.reportError(error)
        }
    }

    private let clock = ContinuousClock()

    private func handleLoad(_ request: TrustCacheFSRequest) throws {
        logger.info("Received load request for \(request.bundleURL.path, privacy: .public)")

        let trustCacheURL = try request.trustCacheURL.require("Load request is missing a trust cache URL.")

        let loader = TrustCacheLoader(path: trustCacheURL.path)
        try loader.load()
    }

    private func handleFullChain(_ request: TrustCacheFSRequest) throws {
        logger.info("Received full chain request for \(request.bundleURL.path, privacy: .public)")

        let start = clock.now

        try AppTrust(bundleURL: request.bundleURL).run()

        logger.info("⏱️ Full chain request fulfilled in \(start.formattedDurationToNow, privacy: .public)")
    }
}
