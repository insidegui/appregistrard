import Foundation

struct TrustCacheLoader {
    /// Path to personalized loadable trust cache.
    let path: String

    func load() throws {
        let url = URL(filePath: (path as NSString).expandingTildeInPath as String)
        var isDir = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            throw Error.fileMissing(url)
        }
        guard !isDir.boolValue else {
            throw Error.invalidFile(url)
        }

        do {
            let data = try Data(contentsOf: url)

            let result = AMFIHelper.loadTrustCache(fromImage4Data: data)

            if result != 0 {
                throw Error.AMFI(Int(result))
            }
        } catch let error as Error {
            throw error
        } catch {
            throw Error.fileLoad(url, error)
        }
    }

    enum Error: CustomNSError {
        case fileMissing(_ url: URL)
        case invalidFile(_ url: URL)
        case fileLoad(_ url: URL, _ error: Swift.Error)
        case AMFI(_ code: Int)

        var errorCode: Int {
            switch self {
            case .fileMissing: 1
            case .invalidFile: 2
            case .fileLoad(_, let error): 100 + (error as NSError).code
            case .AMFI(let code): 1000 + code
            }
        }

        static var errorDomain: String { kAppRegistrarSubsystem }

        var errorUserInfo: [String : Any] {
            var info: [String: Any] = [
                NSLocalizedFailureReasonErrorKey: message
            ]
            if case .fileLoad(_, let underlyingError) = self {
                info[NSUnderlyingErrorKey] = underlyingError as NSError
            }
            return info
        }

        var message: String {
            switch self {
            case .fileMissing(let url): "The file couldn't be found at \"\(url.path)\"."
            case .invalidFile(let url): "Invalid file at \"\(url.path)\"."
            case .fileLoad(let url, _): "The file couldn't be loaded from \"\(url.path)\"."
            case .AMFI(let code): "AMFI error \(code)."
            }
        }
    }
}
