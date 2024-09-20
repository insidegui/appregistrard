import Foundation

extension String {
    var resolvedPath: String { (self as NSString).expandingTildeInPath }
    var resolvedURL: URL { URL(filePath: resolvedPath) }
}

struct PathValidationFlags: OptionSet {
    let rawValue: Int

    static let allowDirectory = PathValidationFlags(rawValue: 1 << 0)
    static let requireDirectory = PathValidationFlags(rawValue: 1 << 1)
}

extension String {
    func resolvedExistingFileURL(options: PathValidationFlags = []) throws -> URL {
        let url = self.resolvedURL

        var isDir = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            throw "File doesn't exist at \(url.path)"
        }

        if options.contains(.allowDirectory) {
            if options.contains(.requireDirectory) {
                guard isDir.boolValue else {
                    throw "Input must be a directory, not a file: \(url.path)"
                }
            }
        } else {
            guard !isDir.boolValue else {
                throw "Input must be a file, not a directory: \(url.path)"
            }
        }

        return url
    }
}
