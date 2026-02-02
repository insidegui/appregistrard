import Foundation
import OSLog

final class DaemonServer {
    private let logger = Logger(subsystem: kAppRegistrarSubsystem, category: "DaemonServer")

    static let shared = DaemonServer()

    private let observer = CryptexObserver()

    static let defaultApplicationsSearchPaths: [String] = [
        "/Applications",
        "/System/Applications",
    ]

    private var applicationsSearchPaths: [String] = {
        if let customPath = ProcessInfo.processInfo.environment["CRYPTEX_APPLICATIONS_PATH"] {
            return DaemonServer.defaultApplicationsSearchPaths + [customPath]
        } else {
            return DaemonServer.defaultApplicationsSearchPaths
        }
    }()

    func activate(applicationsPath: String) {
        logger.notice("Daemon started 🥳")

        enableJetsamBypass()

        guard !DeviceLockStateObserver.State.current.unlockedSinceBoot else {
            return activateAFU(applicationsPath: applicationsPath)
        }

        /// If the cryptex was initialized before first unlock, wait for first unlock before attempting any installs,
        /// as those will inevitably fail on BFU state.
        DeviceLockStateObserver.waitForFirstUnlock { [self] error in
            if let error {
                logger.fault("Failed to observe device first unlock for activation. \(error, privacy: .public)")
            } else {
                logger.notice("Device first unlock completed! Continuing daemon startup...")

                activateAFU(applicationsPath: applicationsPath)
            }
        }
    }

    private func activateAFU(applicationsPath: String) {
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

            for searchPath in applicationsSearchPaths {
                let appsURL = url.appending(path: searchPath, directoryHint: .isDirectory)

                var isDir = ObjCBool(false)
                guard FileManager.default.fileExists(atPath: appsURL.path, isDirectory: &isDir) else {
                    logger.notice("No \(searchPath, privacy: .public) directory for \(name, privacy: .public)")
                    continue
                }
                guard isDir.boolValue else {
                    logger.notice("\(searchPath, privacy: .public) not a directory for \(name, privacy: .public)")
                    continue
                }

                let registration = AppRegistration(
                    sourcePath: appsURL.path,
                    sourceIsAbsolutePath: true,
                    destinationPath: nil,
                    useInstallCoordination: ProcessInfo.appregistrard_useInstallCoordination
                )

                try registration.run()
            }
        } catch {
            logger.error("Error handling registrations for \(name, privacy: .public): \(error, privacy: .public)")
        }
    }
}

extension ProcessInfo {
    static let appregistrard_useInstallCoordination = processInfo.environment["APPREGISTRARD_DISABLE_INSTALLCOORDINATION"] != "1"
}
