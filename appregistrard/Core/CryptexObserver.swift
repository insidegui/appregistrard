import Foundation
import OSLog

final class CryptexObserver: NSObject {
    private let logger = Logger(subsystem: kAppRegistrarSubsystem, category: "CryptexObserver")

    private let cryptexMountRoot = URL(filePath: "/private/var/run/com.apple.security.cryptexd/mnt")

    private lazy var knownCryptexMountPaths = Set<String>()

    private var mountHandler: ((URL) -> Void)? = nil

    func activate(mountHandler: @escaping (URL) -> Void) {
        guard self.mountHandler == nil else {
            logger.fault("Attempting to activate more than once")
            return
        }

        self.mountHandler = mountHandler

        logger.debug("Activating cryptex observer")

        enumerateMountedCryptexes()

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), selfPtr, { center, ptr, name, object, userInfo in
            let observer = unsafeBitCast(ptr, to: CryptexObserver.self)
            guard let name else {
                observer.logger.fault("Received a nameless notification!")
                return
            }

            observer.logger.notice("Received notification: \(name.rawValue, privacy: .public)")

            observer.enumerateMountedCryptexes()
        }, "com.apple.mobile.cryptex_mounted" as CFString, nil, .deliverImmediately)
    }

    private let manager = FileManager()

    private func enumerateMountedCryptexes() {
        do {
            guard manager.fileExists(atPath: cryptexMountRoot.path) else {
                throw "Cryptex mount root not found at \(cryptexMountRoot). Entitlement issue?"
            }

            let contents = try manager.contentsOfDirectory(at: cryptexMountRoot, includingPropertiesForKeys: nil)

            for candidate in contents {
                guard !knownCryptexMountPaths.contains(candidate.path) else { continue }

                knownCryptexMountPaths.insert(candidate.path)

                do {
                    let children = try manager.contentsOfDirectory(at: candidate, includingPropertiesForKeys: nil)

                    guard !children.isEmpty else {
                        logger.debug("Ignoring empty mount \(candidate.lastPathComponent, privacy: .public)")
                        continue
                    }

                    logger.info("Found new cryptex mount: \(candidate.lastPathComponent, privacy: .public)")

                    guard let mountHandler else {
                        logger.fault("We don't have a mount handler!")
                        return
                    }

                    mountHandler(candidate)
                } catch {
                    logger.error("Error processing candidate mount \(candidate.lastPathComponent, privacy: .public): \(error, privacy: .public)")
                }
            }
        } catch {
            logger.error("Error enumerating mounted cryptexes: \(error, privacy: .public)")
        }
    }
}
