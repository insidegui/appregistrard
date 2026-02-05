import Foundation

struct UnixUser: CustomStringConvertible {
    struct Failure: LocalizedError, CustomStringConvertible {
        var failureReason: String?

        init(_ reason: String) {
            self.failureReason = reason
        }

        var description: String { failureReason ?? "" }
    }
    private(set) var name: String
    private(set) var dir: String?
    private(set) var uid: uid_t
    private(set) var gid: gid_t

    init(name: String) throws {
        guard let pw = getpwnam(name)?.pointee else {
            throw Failure("getpwnam failed for \"\(name)\"")
        }

        if let pwName = pw.pw_name {
            self.name = String(cString: pwName)
        } else {
            self.name = name
        }

        if let pwDir = pw.pw_dir {
            self.dir = String(cString: pwDir)
        }

        self.uid = pw.pw_uid
        self.gid = pw.pw_gid
    }

    var description: String { "\(name) (gid: \(gid); uid: \(uid))" }
}
