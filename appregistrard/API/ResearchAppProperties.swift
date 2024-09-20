import Foundation

/// Represents the `ResearchApp` dictionary that can be included in an app's Info.plist
/// in order to define installation details for `appregistrard`.
/// This Info.plist definition is optional.
///
/// Example dictionary:
/// ```xml
/// <?xml version="1.0" encoding="UTF-8"?>
/// <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
/// <plist version="1.0">
/// <dict>
///     <key>Removable</key>
///     <true/>
///     <key>WantsContainer</key>
///     <true/>
/// </dict>
/// </plist>
/// ```
struct ResearchAppProperties {
    /// `ResearchApp.Removable` key.
    var isRemovable: Bool
    /// `ResearchApp.WantsContainer` key.
    var wantsContainer: Bool
    /// `ResearchApp.SystemApp` key.
    var isSystemApp: Bool

    init(isRemovable: Bool = true, wantsContainer: Bool = true, isSystemApp: Bool = false) {
        self.isRemovable = isRemovable
        self.wantsContainer = wantsContainer
        self.isSystemApp = isSystemApp
    }
}

// MARK: - Parsing

extension ResearchAppProperties {
    init(bundle: Bundle) {
        self.init(infoDictionary: bundle.infoDictionary)
    }

    init(infoDictionary: [String: Any]?) {
        guard let researchDict = infoDictionary?["ResearchApp"] as? [String: Any] else {
            self.init()
            return
        }

        self.init(dictionary: researchDict)
    }

    init(dictionary: [String: Any]) {
        self.isRemovable = dictionary["Removable"] as? Bool ?? true
        self.wantsContainer = dictionary["WantsContainer"] as? Bool ?? true
        self.isSystemApp = dictionary["SystemApp"] as? Bool ?? false
    }
}

extension Bool {
    var yesOrNo: String { self ? "Yes" : "No" }
}

extension ResearchAppProperties: CustomStringConvertible {
    var description: String {
        "Removable: \(isRemovable.yesOrNo), Container: \(wantsContainer.yesOrNo), System: \(isSystemApp.yesOrNo)"
    }
}

extension Bundle {
    /// The research app properties defined by this app bundle.
    var researchAppProperties: ResearchAppProperties { ResearchAppProperties(bundle: self) }
}
