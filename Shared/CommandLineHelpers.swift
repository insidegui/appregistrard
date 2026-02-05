import Foundation

extension String {
    var resolvedURL: URL {
        URL(fileURLWithPath: (self as NSString).expandingTildeInPath)
    }
}

// MARK: - Benchmarking

extension ContinuousClock.Instant {
    var formattedDurationToNow: String {
        duration(to: .now)
            .formatted(.units(allowed: [.seconds, .milliseconds]))
    }
}

// MARK: - File URLs

extension URL {
    var exists: Bool { isExistingFile || isExistingDirectory }

    var isExistingFile: Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { return false }
        return !isDirectory.boolValue
    }

    var isExistingDirectory: Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { return false }
        return isDirectory.boolValue
    }

    @discardableResult
    func ensureExistingFile() throws -> Self {
        try isExistingFile.require("File doesn't exist at \(path).")
        return self
    }

    @discardableResult
    func ensureExistingDirectory() throws -> Self {
        try isExistingDirectory.require("Directory doesn't exist at \(path).")
        return self
    }

    @discardableResult
    func creatingDirectoryIfNeeded() throws -> Self {
        guard !isExistingDirectory else { return self }
        try FileManager.default.createDirectory(at: self, withIntermediateDirectories: true)
        return self
    }

    @discardableResult
    func deletingIfExisting() throws -> Self {
        guard isExistingFile else { return self }

        try FileManager.default.removeItem(at: self)

        return self
    }
}

func withCustomError<T>(perform closure: @autoclosure () throws -> T, error customError: (Error) -> Error) throws -> T {
    do {
        return try closure()
    } catch {
        throw customError(error)
    }
}

// MARK: - Output

func printerr(_ input: Any...) {
    fputs(input.map({ String(describing: $0) }).joined(separator: " ") + "\n", stderr)
}

extension String {
    struct PathValidationFlags: OptionSet {
        let rawValue: Int

        static let allowDirectory = PathValidationFlags(rawValue: 1 << 0)
        static let requireDirectory = PathValidationFlags(rawValue: 1 << 1)
    }
    
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
