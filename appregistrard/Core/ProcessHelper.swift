import Foundation

struct ProcessHelper {
    static func terminateProcess(withBundleIdentifier identifier: String) throws {
        let predicate = RBSProcessPredicate(matchingBundleIdentifier: identifier)
        let context = RBSTerminateContext.defaultContext(withExplanation: "appregistrard")
        let request = RBSTerminateRequest(predicate: predicate, context: context)
        try request.execute()
    }
}
