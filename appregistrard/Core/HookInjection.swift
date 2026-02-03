import Foundation
import OSLog
import LaunchKitLite

/// Configures launchd environment for injecting `libAppRegistrarHooks.dylib` into installd.
struct HookInjection {
    static let dylibName = "libAppRegistrarHooks"
    static let securityresearchdLibPath = "/private/var/db/com.apple.securityresearchd/lib"

    static let logger = Logger(subsystem: kAppRegistrarSubsystem, category: String(describing: HookInjection.self))

    static func enable() throws {
        let launchd = BootstrapServer(domain: .user)

        let mountPath = try ProcessInfo.processInfo.cryptexMountPath
        let sourceDylibPath = mountPath + "/usr/lib/\(dylibName).dylib"

        /// Copy dylib into the same location that `securityresearchd` would install it, as `installd` won't be able to load it from our cryptex mount.
        let installedDylibDir = securityresearchdLibPath + "/\(dylibName)"
        let installedDylibPath = installedDylibDir + "/\(dylibName).dylib"

        logger.debug("Copying dylib into accessible location: \(installedDylibPath, privacy: .public)")

        if !FileManager.default.fileExists(atPath: installedDylibDir) {
            try FileManager.default.createDirectory(atPath: installedDylibDir, withIntermediateDirectories: true)
        }

        if FileManager.default.fileExists(atPath: installedDylibPath) {
            try FileManager.default.removeItem(atPath: installedDylibPath)
        }
        try FileManager.default.copyItem(atPath: sourceDylibPath, toPath: installedDylibPath)

        logger.debug("Successfully installed dylib at \(installedDylibPath, privacy: .public)")

        logger.debug("Enabling hook injection for dylib at \(installedDylibPath, privacy: .public)")

        var insertLibraries = try launchd.getEnv(variable: "DYLD_INSERT_LIBRARIES") ?? ""

        logger.debug("Environment before hook injection: \(insertLibraries.isEmpty ? "<empty>" : insertLibraries)")

        var libraries: [String] = insertLibraries.components(separatedBy: ":")
        let previousLibraries = libraries

        if let index = libraries.firstIndex(where: { $0.hasSuffix(dylibName + ".dylib") }) {
            if libraries[index] != installedDylibPath {
                logger.debug("Found stale dylib path in DYLD_INSERT_LIBRARIES: \(libraries[index]), replacing with new one")
                libraries[index] = installedDylibPath
            } else {
                logger.debug("Dylib already injected, skipping environment update")
            }
        } else {
            logger.debug("Dylib not injected, updating environment")
            libraries.append(installedDylibPath)
        }

        if libraries != previousLibraries {
            logger.debug("Writing new launchd environment")

            insertLibraries = libraries.joined(separator: ":")

            try launchd.setEnv(variable: "DYLD_INSERT_LIBRARIES", value: insertLibraries)

            let newEnv = try launchd.getEnv(variable: "DYLD_INSERT_LIBRARIES")

            logger.debug("Environment after hook injection: \(newEnv ?? "<nil>")")
        }

        logger.debug("Kickstarting installd")

        do {
            let pid = try launchd.kickstart(service: "com.apple.mobile.installd")

            logger.info("Kickstarted installd with pid \(pid, privacy: .public)")
        } catch {
            logger.error("installd kickstart failed: \(error, privacy: .public)")
        }
    }
}
