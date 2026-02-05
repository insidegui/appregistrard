import Foundation
internal import TrustCacheGenerator
internal import AuthInstallKit
import OSLog

struct TrustCachePayloadGenerator {
    private let logger = Logger(subsystem: kAppRegistrarSubsystem, category: "TrustCachePayloadGenerator")

    let generator: TrustCacheGenerator
    let tag: String

    static let defaultTag = "ltrs"

    init(input: URL, tag: String = TrustCachePayloadGenerator.defaultTag) {
        self.generator = TrustCacheGenerator(version: .version1, inputURL: input)
        self.tag = tag
    }

    @discardableResult
    func generate(writingTo outputURL: URL) throws -> URL {
        let data = try generator.generate()

        let im4pData = try Image4Encoder.encodePayload(data, tag: tag, version: "cptx")

        try im4pData.write(to: outputURL, options: .atomic)

        return outputURL
    }
}
