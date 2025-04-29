import Foundation
import OSLog

final class CryptexObserver: NSObject {
    private let logger = Logger(subsystem: kAppRegistrarSubsystem, category: "CryptexObserver")
    private let defaults = UserDefaults.standard

    private let cryptexMountRoot = URL(filePath: "/private/var/run/com.apple.security.cryptexd/mnt")

    private lazy var knownCryptexMountPaths = Set<String>()

    private var mountHandler: ((URL) -> Void)? = nil

    private var isPerBootSessionStorageEnabled: Bool = true

    func activate(perBootSessionStorage: Bool = true, mountHandler: @escaping (URL) -> Void) {
        guard self.mountHandler == nil else {
            logger.fault("Attempting to activate more than once")
            return
        }

        self.isPerBootSessionStorageEnabled = perBootSessionStorage
        self.mountHandler = mountHandler

        logger.debug("Activating cryptex observer")

        self.knownCryptexMountPaths = loadPersistedCryptexMountPaths()

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
                persistCryptexMountPaths(knownCryptexMountPaths)

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

    // MARK: - Persistence

    private let bootSessionUUIDKey = "knownCryptexMountPathsBootSessionUUID"
    private let knownCryptexMountPathsKey = "knownCryptexMountPaths"

    private func resetPersistedCryptexMountPathsIfNeeded() {
        guard isPerBootSessionStorageEnabled else { return }
        
        guard let bootSessionUUID = currentBootSessionUUID() else {
            logger.fault("Failed to read boot session UUID, cryptex paths list will never be reset.")
            return
        }

        let storageBootSessionUUID = defaults.string(forKey: bootSessionUUIDKey)

        guard storageBootSessionUUID != bootSessionUUID else {
            return
        }

        logger.notice("Resetting persisted cryptex mount paths: running in new boot session \(bootSessionUUID, privacy: .public) (previous session: \(storageBootSessionUUID ?? "<nil>", privacy: .public)).")

        defaults.set([String](), forKey: knownCryptexMountPathsKey)
        defaults.set(bootSessionUUID, forKey: bootSessionUUIDKey)
        defaults.synchronize()
    }

    private func loadPersistedCryptexMountPaths() -> Set<String> {
        resetPersistedCryptexMountPathsIfNeeded()

        guard let list = defaults.stringArray(forKey: knownCryptexMountPathsKey) else {
            return []
        }

        logger.debug("Loaded \(list.count, privacy: .public) known cryptex mount paths")

        return Set(list)
    }

    private func persistCryptexMountPaths(_ paths: Set<String>) {
        logger.debug("Persisting \(paths.count, privacy: .public) known cryptex mount paths")

        defaults.set(Array(paths), forKey: knownCryptexMountPathsKey)
        defaults.synchronize()
    }

    private func currentBootSessionUUID() -> String? {
        let key = "kern.bootsessionuuid"
        var size = 0

        var err = sysctlbyname(key, nil, &size, nil, 0)
        guard err == 0 else {
            logger.fault("\(key) read failed with code \(err, privacy: .public)")
            return nil
        }

        var buffer = [CChar](repeating: 0, count: size)
        err = sysctlbyname(key, &buffer, &size, nil, 0)
        guard err == 0 else {
            logger.fault("\(key) read failed with code \(err, privacy: .public)")
            return nil
        }

        return String(cString: buffer)
    }
}
