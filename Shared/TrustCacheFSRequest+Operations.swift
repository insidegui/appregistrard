import Foundation
import OSLog

@objc public extension TrustCacheFSRequest {
    @nonobjc private static let logger = Logger(subsystem: kAppRegistrarSubsystem, category: "TrustCacheFSRequest+Operations")

    func delete() throws {
        guard FileManager.default.fileExists(atPath: requestURL.path) else { return }

        /// Attempting to coordinate deletion was just hanging, so just delete it directly.
        try FileManager.default.removeItem(at: requestURL)
    }

    func reportError(_ error: Error) {
        do {
            try "\(error)".write(to: errorURL, atomically: true, encoding: .utf8)
        } catch {
            Self.logger.fault("Error writing error report for \(self.id, privacy: .public) - \(error, privacy: .public)")
        }
    }

    private static let performQueue = DispatchQueue(label: "TrustCacheFSPerform", qos: .userInitiated, target: .global())

    func performAndWaitSync() throws {
        let observedFileURL = try write()

        let maxWaitSeconds: Int = 10

        let debugName = bundleURL.deletingPathExtension().lastPathComponent

        Self.logger.notice("[\(debugName, privacy: .public)] \(#function, privacy: .public) called for \(self.bundleURL.path, privacy: .public)")

        let sema = DispatchSemaphore(value: 0)
        var error: NSError?

        func check() {
            guard !FileManager.default.fileExists(atPath: errorURL.path) else {
                do {
                    Self.logger.info("Found error report at \(self.errorURL.path, privacy: .public)")

                    let errorMessage = try String(contentsOf: errorURL, encoding: .utf8)
                    error = NSError.appregistrar(code: 97, errorMessage)
                } catch let _error {
                    Self.logger.fault("Collected error report file, but failed to read it in order to report the error properly. \(_error, privacy: .public)")
                    error = NSError.appregistrar(code: 98, "Trust cache request failed, but error details could not be obtained.")
                }

                sema.signal()

                return
            }

            guard FileManager.default.fileExists(atPath: observedFileURL.path) else {
                sema.signal()
                return
            }

            Self.performQueue.asyncAfter(deadline: .now() + .milliseconds(100)) {
                check()
            }
        }

        Self.performQueue.async {
            check()
        }

        let result = sema.wait(timeout: .now() + .seconds(maxWaitSeconds))

        guard result == .success else {
            Self.logger.error("[\(debugName, privacy: .public)] Request timed out after \(maxWaitSeconds, privacy: .public) seconds")
            throw NSError.appregistrar(code: 99, "The request timed out.")
        }

        if let error {
            Self.logger.error("[\(debugName, privacy: .public)] Request failed - \(error, privacy: .public)")
            throw error
        } else {
            Self.logger.notice("[\(debugName, privacy: .public)] Request fulfilled! :)")
        }
    }
}

extension TrustCacheFSRequest {

    /// Only `appregistrard` should be writing requests directly without going through ``performAndWait(completion:)``,
    /// that's why this `write()` method is not exposed to Objective-C.
    @discardableResult
    func write() throws -> URL {
        let data = try PropertyListEncoder.trustCacheFS.encode(self)

        var error: NSError?
        coordinator.coordinate(writingItemAt: requestURL, options: .forReplacing, error: &error) { url in
            do {
                try TrustCacheFSRequest.createRequestsDirectoryIfNeeded()

                try data.write(to: url)
            } catch let _error {
                error = _error as NSError
                Self.logger.error("Error writing request - \(error, privacy: .public)")
            }
        }

        if let error {
            Self.logger.error("Error coordinating request write - \(error, privacy: .public)")
            throw error
        }

        return requestURL
    }
}

extension PropertyListEncoder {
    static let trustCacheFS: PropertyListEncoder = {
        let e = PropertyListEncoder()
        e.outputFormat = .binary
        return e
    }()
}

extension PropertyListDecoder {
    static let trustCacheFS = PropertyListDecoder()
}

extension NSError {
    static func appregistrar(code: Int, _ message: String) -> NSError {
        NSError(domain: kAppRegistrarSubsystem, code: code, userInfo: [NSLocalizedFailureReasonErrorKey: message])
    }
}

// MARK: - Directory Creation And Ownership

extension TrustCacheFSRequest {
    static func createRequestsDirectoryIfNeeded() throws {
        let url = TrustCacheFSConstants.requestsDirectoryURL

        guard !FileManager.default.fileExists(atPath: url.path) else { return }

        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        /// If we're not running in `installd`, then the ownership of the directory must be tweaked so
        /// that both `installd` and `appregistrard` can read and write on the directory.
        ///
        /// Otherwise if it's created by `appregistrard` the ownership will be for `root` and then `installd`
        /// won't be able to write request files.
        guard ProcessInfo.processInfo.processName != "installd" else { return }

        Self.logger.debug("Setting ownership to _installd on \(url.path, privacy: .public)")

        do {
            let user = try UnixUser(name: "_installd")

            Self.logger.debug("Setting ownership to \(user, privacy: .public) on \(url.path, privacy: .public)")

            let err = chown(url.path, user.uid, user.gid)

            guard err == 0 else {
                throw "chown failed with code \(err)"
            }
        } catch {
            Self.logger.fault("Error setting ownership to _installd on \(url.lastPathComponent, privacy: .public) directory - \(error, privacy: .public)")
            throw error
        }
    }
}
