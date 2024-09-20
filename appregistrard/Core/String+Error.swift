import Foundation

extension String: @retroactive LocalizedError {
    public var errorDescription: String? { self }
    public var failureReason: String? { self }
}
