import UIKit
import OSLog

struct Jindo {
    private static let logger = Logger(subsystem: kAppRegistrarSubsystem, category: "Jindo")

    private static var currentNotification: CFUserNotification?
    private static var currentNotificationSource: CFRunLoopSource?

    private static func cfUserNotificationCallback(_ note: CFUserNotification?, _ flags: CFOptionFlags) {
        logger.debug("Received CFUserNotification callback for \(String(describing: note), privacy: .public) with \(String(describing: flags), privacy: .public)")
    }

    static func presentAppInstalledNotification(appNames: [String]) {
        guard !UserDefaults.standard.bool(forKey: "DisableNotification") else {
            logger.debug("App installed notification disabled")
            return
        }

        guard !appNames.isEmpty else {
            logger.warning("No app names in app installed notification")
            return
        }

        logger.info("Requesting app installed notification for \(appNames.joined(separator: ", "))")

        let title: String
        let message: String

        if appNames.count == 1 {
            title = "\(appNames[0]) Installed"
            message = "The app \(appNames[0]) was successfully installed."
        } else {
            title = "\(appNames.count) Apps Installed"
            if appNames.count > 3 {
                let remaining = appNames.count - 2
                let lastThree = appNames.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }).suffix(2)
                message = "\(lastThree.joined(separator: ", ")) and \(remaining) more apps were successfully installed."
            } else {
                message = "\(appNames.joined(separator: ", ")) were successfully installed."
            }
        }

        let aperture = SBSUserNotificationSystemApertureContentDefinition()
        aperture.alertHeader = title
        aperture.alertMessage = message
        aperture.preventsAutomaticDismissal = false

        let content = aperture.build()

        let params: [String: Any] = [
            "AlertTopMost": true,
            "SBUserNotificationAllowMenuButtonDismissal": true,
            "SBUserNotificationAllowDuringTransitionAnimations": true,
            "SBUserNotificationAllowLockscreenDismissal": true,
            "SBUserNotificationWakeDisplay": true,
            "SBUserNotificationIgnoresQuietMode": true,
            "SBUserNotificationBehavesSuperModally": true,
            "SBUserNotificationSystemAperturePresentation": true,
            "SBUserNotificationSystemApertureContentDefinition": content
        ]

        var error: Int32 = 0
        let note = soft_CFUserNotificationCreate(kCFAllocatorDefault, 0, 0, &error, params as CFDictionary).takeRetainedValue()

        guard error == 0 else {
            logger.error("CFUserNotificationCreate error code \(error, privacy: .public)")
            return
        }

        Self.currentNotification = note

        let source = soft_CFUserNotificationCreateRunLoopSource(kCFAllocatorDefault, note, { note, flags in
            Self.cfUserNotificationCallback(note, flags)
        }, 0).takeRetainedValue()

        Self.currentNotificationSource = source

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }
}
