import Foundation
import CryptoKit
import OSLog
internal import TatsuKit
internal import AuthInstallKit
internal import DeviceIdentityKit

struct TSSPersonalizationError: Error {
    var code: Int
    var message: String
    var requestData: Data
    var responseData: Data
}

struct TrustCachePersonalizer {
    private let logger = Logger(subsystem: kAppRegistrarSubsystem, category: "TrustCachePersonalizer")
    
    let payloadURL: URL
    let tag: String
    let outputURL: URL

    init(payloadURL: URL, tag: String = "ltrs", outputURL: URL) {
        self.payloadURL = payloadURL
        self.tag = tag
        self.outputURL = outputURL
    }

    func request(for identity: DeviceIdentity) throws -> TatsuRequest {
        let payloadData = try Data(contentsOf: payloadURL, options: .mappedIfSafe)
        let payloadDigest = payloadData.sha384Digest()

        return TatsuRequest(
            boardID: Int(identity.boardID),
            chipID: Int(identity.chipID),
            ecid: identity.ecid,
            apNonce: identity.apNonce,
            securityMode: identity.securityMode,
            productionMode: identity.productionMode,
            uidMode: false,
            securityDomain: identity.securityDomain,
            sikaFuse: identity.sikaFuse > 0 ? Int(identity.sikaFuse) : nil,
            components: [
                "LoadableTrustCache": TatsuRequest.Component(
                    digest: payloadDigest,
                    effectiveProductionMode: identity.productionMode,
                    effectiveSecurityMode: identity.securityMode,
                    trusted: true
                )
            ]
        )
    }

    func personalize(for identity: DeviceIdentity, timeout: TimeInterval = 30, completion: @escaping (Result<URL, Error>) -> Void) {
        do {
            let request = try self.request(for: identity)

            logger.debug("TSS request:\n\((request.dictionary as NSDictionary).debugDescription, privacy: .public)")

            if TrustCacheDebuggingEnabled() {
                /// The check for ``TrustCacheDebuggingEnabled()`` already guarantees that the folder exists, so no need to check/create here.
                let debugPlistURL = URL(filePath: String.appRegistrarRequestsPath)
                    .appending(path: TrustCacheFSConstants.debugFolderName, directoryHint: .isDirectory)
                    .appending(path: "TSSRequest_\(Int(Date.now.timeIntervalSinceReferenceDate)).plist")

                logger.info("Debugging enabled, saving TSS request plist to \(debugPlistURL.path(percentEncoded: false), privacy: .public)")

                do {
                    let data = try PropertyListSerialization.data(fromPropertyList: request.dictionary, format: .xml, options: 0)
                    try data.write(to: debugPlistURL, options: .atomic)
                } catch {
                    logger.error("Error writing TSS request debug file - \(error, privacy: .public)")
                }
            }

            let client = TatsuClient()

            client.send(request, timeout: timeout) { result in
                switch result {
                case .success(let tssResult):
                    do {
                        let ticketDict = try tssResult.response.getDictionary()

                        try Image4Encoder.stitchTicket(
                            ticketDict,
                            payloadURL: payloadURL,
                            payloadTag: tag,
                            outputURL: outputURL
                        )

                        completion(.success(outputURL))
                    } catch {
                        logger.debug("Caught TSS failure, delivering detailed error for \(error)")

                        let tssError = TSSPersonalizationError(
                            code: tssResult.response.status,
                            message: tssResult.response.message,
                            requestData: tssResult.requestData,
                            responseData: tssResult.responseData
                        )

                        completion(.failure(tssError))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    @discardableResult
    func personalizeSync(for identity: DeviceIdentity, timeout: TimeInterval = 30) throws -> URL {
        let sema = DispatchSemaphore(value: 0)

        var error: Error? = nil

        personalize(for: identity, timeout: timeout) { result in
            switch result {
            case .success:
                break
            case .failure(let failure):
                error = failure
            }

            sema.signal()
        }

        let result = sema.wait(timeout: .now() + timeout)

        try (result != .timedOut)
            .require("Timed out waiting for TSS response.")

        if let error {
            throw error
        } else {
            return outputURL
        }
    }
}

extension Data {
    func sha384Digest() -> Data {
        Data(SHA384.hash(data: self).map({ $0 }))
    }
}
