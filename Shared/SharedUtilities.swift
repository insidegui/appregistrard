import Foundation

extension Optional {
    func require(_ error: Error) throws -> Wrapped {
        guard let self else { throw error }
        return self
    }
}

extension Bool {
    func require(_ error: Error) throws {
        if !self { throw error }
    }
}

extension String: @retroactive LocalizedError {
    public var failureReason: String? { self }
}
