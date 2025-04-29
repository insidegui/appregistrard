import Foundation
import notify

struct DeviceLockStateObserver {
    struct State: Hashable, CustomStringConvertible {
        let unlockedSinceBoot: Bool
        let keyBagState: MKBDeviceLockState

        init(unlockedSinceBoot: Bool, keyBagState: MKBDeviceLockState) {
            self.unlockedSinceBoot = unlockedSinceBoot
            self.keyBagState = keyBagState
        }

        static var current: State {
            State(
                unlockedSinceBoot: MKBDeviceUnlockedSinceBoot() == 1,
                keyBagState: MKBGetDeviceLockState(nil)
            )
        }

        var description: String { "Unlocked since boot? \(unlockedSinceBoot ? "YES" : "NO") | KeyBag State: \(keyBagState)" }
    }

    enum Failure: LocalizedError {
        case notifyRegister(_ code: UInt32)

        var errorDescription: String? {
            switch self {
            case .notifyRegister(let code): "Failed to register for MKB notification. Error code \(code)."
            }
        }
    }

    private let token: Int32

    init(queue: DispatchQueue = .main, callback: @escaping (State) -> Void) throws(Failure) {
        var token = Int32(0)
        let err = notify_register_dispatch("com.apple.mobile.keybagd.lock_status", &token, queue) { _ in
            callback(.current)
        }
        guard err == 0 else { throw .notifyRegister(err) }
        self.token = token
    }

    var currentState: State { .current }

    func invalidate() {
        notify_cancel(token)
    }
}

// MARK: - One-Off Observations

extension DeviceLockStateObserver {
    static func waitForFirstUnlock(callback: @escaping (Error?) -> ()) {
        wait(for: { $0.unlockedSinceBoot }, callback: callback)
    }

    static func waitForFirstUnlock() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            waitForFirstUnlock() { error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    static func wait(forKeyBagState keyBagState: MKBDeviceLockState, callback: @escaping (Error?) -> ()) {
        wait(for: { $0.keyBagState == keyBagState }, callback: callback)
    }

    static func wait(forKeyBagState keyBagState: MKBDeviceLockState) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            wait(forKeyBagState: keyBagState) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    static func wait(for predicate: @escaping (State) -> Bool, callback: @escaping (Error?) -> ()) {
        /// If state has already been satisfied, finish right away.
        guard !predicate(.current) else {
            callback(nil)
            return
        }

        do {
            let sema = DispatchSemaphore(value: 0)

            let queue = DispatchQueue(label: "DeviceLockStateObserver", qos: .userInitiated, target: .global(qos: .userInitiated))

            /// Create observer on dedicated queue to ensure semaphore wait doesn't prevent ability to receive the notification.
            let observer = try queue.sync {
                try DeviceLockStateObserver(queue: queue) { state in
                    if predicate(state) {
                        sema.signal()
                    }
                }
            }

            sema.wait()

            observer.invalidate()

            callback(nil)
        } catch {
            callback(error)
        }
    }

    static func wait(for predicate: @escaping (State) -> Bool) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            wait(for: predicate) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }
}
