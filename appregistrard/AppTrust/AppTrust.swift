import Foundation
import OSLog
internal import DeviceIdentityKit

/// Combines all operations needed to trust an app on device:
/// - Generates trust cache payload
/// - Personalizes trust cache via TSS
/// - Loads trust cache via AMFI
struct AppTrust {
    private let logger = Logger(subsystem: kAppRegistrarSubsystem, category: "AppTrust")

    let bundleURL: URL
    private let tempDirURL: URL
    private let bundleName: String

    init(bundleURL: URL) {
        self.bundleURL = bundleURL
        self.bundleName = bundleURL.lastPathComponent
        self.tempDirURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("appregistrard")
            .appendingPathComponent(bundleURL.deletingPathExtension().lastPathComponent + "_\(Int(Date.now.timeIntervalSinceReferenceDate))")
    }

    func run() throws {
        logger.info("Running for \(bundleName, privacy: .public)")

        try tempDirURL.creatingDirectoryIfNeeded()

        logger.debug("Temporary directory: \(tempDirURL.path, privacy: .public)")

        let outputURL = tempDirURL.appendingPathComponent("trustcache.im4p")

        logger.debug("Trust cache payload will be written to: \(outputURL.path, privacy: .public)")

        let im4pURL = try TrustCachePayloadGenerator(input: bundleURL).generate(writingTo: outputURL)

        let img4URL = im4pURL.deletingPathExtension().appendingPathExtension("img4")

        logger.debug("Personalized trust cache will be written to: \(img4URL.path, privacy: .public)")

        let identity = try DeviceIdentity.current

        logger.info("Device identity: BoardID = \(identity.boardID, privacy: .public), ChipID = \(identity.chipID, privacy: .public), ECID = \(String(format: "0x%02x", identity.ecid))")

        guard identity.ecid != 0 else {
            throw "Couldn't determine ECID."
        }

        logger.info("Personalization nonce: \(identity.apNonce.hexString, privacy: .public)")

        do {
            try TrustCachePersonalizer(payloadURL: im4pURL, outputURL: img4URL)
                .personalizeSync(for: identity)
        } catch let error as TSSPersonalizationError {
            logger.error("Trust cache personalization TSS failed with code \(error.code, privacy: .public). \(error.message, privacy: .public)")

            logger.error("Trust cache personalization failed TSS request: \(error.requestData.base64EncodedString(), privacy: .public)")
            logger.error("Trust cache personalization failed TSS response: \(error.responseData.base64EncodedString(), privacy: .public)")
        } catch {
            logger.error("Trust cache personalization failed. \(error, privacy: .public)")

            throw error
        }

        logger.notice("Trust cache personalized successfully, loading...")

        try TrustCacheLoader(path: img4URL.path).load()

        logger.notice("Successfully loaded trust cache for \(bundleName, privacy: .public)")
    }
}

extension Data {
    var hexString: String { map { String(format: "%02x", $0) }.joined() }
}
