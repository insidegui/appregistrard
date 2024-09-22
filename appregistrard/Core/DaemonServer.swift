import Foundation
import OSLog

final class DaemonServer {
    private let logger = Logger(subsystem: kAppRegistrarSubsystem, category: "DaemonServer")

    static let shared = DaemonServer()

    private let observer = CryptexObserver()

    private var applicationsPath: String = {
        if let customPath = ProcessInfo.processInfo.environment["CRYPTEX_APPLICATIONS_PATH"] {
            return customPath
        } else {
            return "/System/Applications"
        }
    }()

    func activate(applicationsPath: String) {
        logger.notice("Daemon started 🥳")

        enableJetsamBypass()

        logger.info("Observing cryptex mounts, applications path is \(applicationsPath, privacy: .public)")

        do {
            try processCryptex(at: URL(filePath: ProcessInfo.processInfo.cryptexMountPath), allowLocal: true)
        } catch {
            logger.fault("Failed to obtain local cryptex mount path")
        }

        observer.activate { [self] url in
            processCryptex(at: url)
        }

        CFRunLoopRun()
    }

    private func processCryptex(at url: URL, allowLocal: Bool = false) {
        let localCryptexPath = try? ProcessInfo.processInfo.cryptexMountPath
        let isLocalCryptex = url.path == localCryptexPath

        let name = isLocalCryptex ? "local cryptex" : url.lastPathComponent

        do {
            if isLocalCryptex {
                guard allowLocal else {
                    logger.debug("Ignoring notification for the appregistrard cryptex itself")
                    return
                }
            }

            logger.notice("Processing \(name)")

            let appsURL = url.appending(path: applicationsPath, directoryHint: .isDirectory)

            var isDir = ObjCBool(false)
            guard FileManager.default.fileExists(atPath: appsURL.path, isDirectory: &isDir) else {
                logger.notice("Ignoring \(name, privacy: .public) because it doesn't have a \(self.applicationsPath, privacy: .public) directory")
                return
            }
            guard isDir.boolValue else {
                logger.notice("Ignoring \(name, privacy: .public) because its \(self.applicationsPath, privacy: .public) path is not a directory")
                return
            }

            let registration = AppRegistration(
                sourcePath: appsURL.path,
                sourceIsAbsolutePath: true,
                destinationPath: nil
            )

            try registration.run()
        } catch {
            logger.error("Error handling registrations for \(name, privacy: .public): \(error, privacy: .public)")
        }
    }
}
