import Foundation

extension ProcessInfo {
    var cryptexMountPath: String {
        get throws {
            #if targetEnvironment(simulator)
            guard let rootPath = ProcessInfo.processInfo.environment["SIMULATOR_ROOT"] else {
                throw "Missing SIMULATOR_ROOT environment variable!"
            }
            return rootPath
            #else
            guard let rootPath = ProcessInfo.processInfo.environment["CRYPTEX_MOUNT_PATH"] else {
                throw "Missing CRYPTEX_MOUNT_PATH environment variable!"
            }
            return rootPath
            #endif
        }
    }
}
