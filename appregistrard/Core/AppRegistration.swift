import Foundation
import OSLog
import UniformTypeIdentifiers
import notify
import ArgumentParser

struct AppRegistration {
    let sourcePath: String
    var sourceIsAbsolutePath: Bool
    let destinationPath: String?

    func run() throws {
        let applicationsPath: String

        if sourceIsAbsolutePath {
            applicationsPath = sourcePath
        } else {
            let rootPath = try ProcessInfo.processInfo.cryptexMountPath
            applicationsPath = "\(rootPath)" + sourcePath
        }

        let applicationsURL = try applicationsPath.resolvedExistingFileURL(options: [.allowDirectory, .requireDirectory])
        let appURLs: [URL]

        /// Handle path being the app bundle itself.
        if applicationsURL.pathExtension.lowercased() == "app" {
            appURLs = [applicationsURL]
        } else {
            appURLs = try FileManager.default.contentsOfDirectory(at: applicationsURL, includingPropertiesForKeys: [], options: [.skipsHiddenFiles, .skipsPackageDescendants])
                .filter { $0.pathExtension.lowercased() == "app" }

            guard !appURLs.isEmpty else {
                logger.warning("Found no apps at \(applicationsURL.path, privacy: .public)")
                return
            }
        }

        logger.notice("Found \(appURLs.count, privacy: .public) app(s) at \(applicationsURL.path)")

        var installedAppURLs = [URL]()

        if let destinationPath {
            let destinationURL = destinationPath.resolvedURL

            if !FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: false)
                let err = chown(destinationURL.path, 501, 501)
                if err != 0 {
                    logger.warning("Failed to chown \(destinationURL.path, privacy: .public): \(err, privacy: .public)")
                }
            }

            for url in appURLs {
                let destURL = destinationURL.appendingPathComponent(url.lastPathComponent)

                do {
                    if FileManager.default.fileExists(atPath: destURL.path) {
                        try FileManager.default.removeItem(at: destURL)
                    }

                    try FileManager.default.copyItem(at: url, to: destURL)

                    installedAppURLs.append(destURL)
                } catch {
                    logger.error("Failed to install \(url.lastPathComponent, privacy: .public) at \(destURL.path, privacy: .public): \(error, privacy: .public)")
                }
            }
        } else {
            installedAppURLs = appURLs
        }

        guard !installedAppURLs.isEmpty else {
            throw "No apps were installed"
        }

        try runLaunchServices(urls: installedAppURLs)
    }

    private func runLaunchServices(urls: [URL]) throws {
        var installedAppNames = [String]()

        for url in urls {
            autoreleasepool {
                do {
                    guard let bundle = Bundle(url: url) else {
                        throw "Failed to construct bundle for \(url.lastPathComponent)"
                    }

                    try bundle.registerWithLaunchServices()

                    installedAppNames.append(url.deletingPathExtension().lastPathComponent)
                } catch {
                    logger.error("Error during registration of \(url.lastPathComponent, privacy: .public): \(error, privacy: .public)")
                }
            }
        }

        Jindo.presentAppInstalledNotification(appNames: installedAppNames)
    }
}

// MARK: - Registration Info

private extension Bundle {
    func registerWithLaunchServices() throws {
        guard let bundleIdentifier = infoDictionary?[kCFBundleIdentifierKey as String] as? String else {
            throw "Info.plist for \(bundleURL.lastPathComponent) has no CFBundleIdentifier"
        }

        /// Ensure preinstalled version is terminated.
        try? ProcessHelper.terminateProcess(withBundleIdentifier: bundleIdentifier)

        let registration = try createLaunchServicesRegistrationDictionary()

        logger.debug("Registration dictionary for \(bundleIdentifier, privacy: .public): \((registration as NSDictionary).description, privacy: .public)")

        if LSApplicationWorkspace.default.registerApplicationDictionary(registration) {
            logger.notice("Successfully registered \(bundleIdentifier, privacy: .public)")

            notify_post("com.apple.mobile.application_installed")
            notify_post("com.apple.itunesstored.application_installed")
        } else {
            logger.warning("Registration failed for \(bundleIdentifier, privacy: .public)")
        }
    }

    func createLaunchServicesRegistrationDictionary() throws -> [String: Any] {
        guard let bundleIdentifier = infoDictionary?[kCFBundleIdentifierKey as String] as? String else {
            throw "Info.plist has no CFBundleIdentifier for \(bundleURL.lastPathComponent)"
        }

        let props = self.researchAppProperties

        logger.notice("Preparing registration of \(bundleIdentifier, privacy: .public) with properties: \(props, privacy: .public)")

        var registration: [String: Any] = [
            "ApplicationType": "System",
            kCFBundleIdentifierKey as String: bundleIdentifier,
            "CompatibilityState": false,
            "Path": bundlePath,
            "IsDeletable": props.isRemovable,
            "ProfileValidated": 1
        ]
        registration["CFBundleShortVersionString"] = infoDictionary?["CFBundleShortVersionString"]
        registration["CFBundleVersion"] = infoDictionary?["CFBundleVersion"]

        if props.wantsContainer {
            logger.notice("Creating containers for \(bundleIdentifier, privacy: .public)")

            do {
                /// Try also: MCMPerUserAppContainer
                let bundleContainer = try MCMAppContainer(identifier: bundleIdentifier, createIfNecessary: true, existed: nil)

                guard let bundleContainerURL = bundleContainer.url else {
                    throw "Bundle container for \(bundleIdentifier) has no URL"
                }

                Thread.sleep(forTimeInterval: 0.2)

                do {
                    logger.notice("Copying app bundle into bundle container at \(bundleContainerURL.path, privacy: .public)")

                    let destinationBundleURL = bundleContainerURL.appending(path: bundleURL.lastPathComponent)
                    
                    if FileManager.default.fileExists(atPath: destinationBundleURL.path) {
                        try FileManager.default.removeItem(at: destinationBundleURL)
                    }

                    try FileManager.default.copyItem(at: bundleURL, to: destinationBundleURL)
                    registration["Path"] = destinationBundleURL.path
                } catch {
                    logger.fault("Failed to copy app into bundle container: \(error, privacy: .public)")

                    throw error
                }

                let dataContainer = try MCMAppDataContainer(identifier: bundleIdentifier, createIfNecessary: true, existed: nil)

                guard let dataContainerURL = dataContainer.url else {
                    throw "Data container for \(bundleIdentifier) has no URL"
                }

                registration["BundleContainer"] = bundleContainerURL.path(percentEncoded: false)
                registration["Container"] = dataContainerURL.path(percentEncoded: false)
                registration["IsContainerized"] = true
            } catch {
                throw "Container creation failed for \(bundleIdentifier): \(error)"
            }
        }

        logger.notice("Finding app extensions for \(bundleIdentifier)")

        addExtensionDictionaries(to: &registration)

        return registration
    }

    /// If this bundle represents a PluginKit plugin, returns the registration dictionary
    /// that can be used as part of `_LSBundlePlugins` when registering the containing app.
    func pluginKitRegistrationInfo(withParent parent: Bundle, parentBundleURL: URL) throws -> (bundleID: String, dictionary: [String: Any])? {
        guard let parentID = parent.bundleIdentifier else { return nil }
        guard let bundleID = self.bundleIdentifier else { return nil }

        guard let infoDictionary else { return nil }
        guard infoDictionary["NSExtension"] != nil else { return nil }

        let container = try MCMPluginKitPluginDataContainer(identifier: bundleID, createIfNecessary: true, existed: nil)

        guard let dataContainerURL = container.url else {
            throw "Data container for extension \(bundleID) has no URL"
        }

        /// Here we reconstruct the bundle path based on the parent bundle URL, as the parent bundle
        /// might be inside of a bundle container by now.
        let effectivePath = parentBundleURL
            .appendingPathComponent("PlugIns")
            .appendingPathComponent(bundleURL.lastPathComponent)
            .path

        var dict: [String: Any] = [
            "ApplicationType": "PluginKitPlugin",
            "CFBundleIdentifier": bundleID,
            "CompatibilityState": false,
            "Path": effectivePath,
            "PluginOwnerBundleID": parentID,
            "Container": dataContainerURL.path(percentEncoded: false),
            "IsContainerized": true,
            "ProfileValidated": 1
        ]
        dict["CFBundleShortVersionString"] = infoDictionary["CFBundleShortVersionString"]
        dict["CFBundleVersion"] = infoDictionary["CFBundleVersion"]

        return (bundleID, dict)
    }

    /// Enumerates app extensions and adds them to the app's registration dictionary.
    private func addExtensionDictionaries(to registration: inout [String: Any]) {
        let dirURL = bundleURL.appending(path: "PlugIns", directoryHint: .isDirectory)

        guard FileManager.default.fileExists(atPath: dirURL.path) else { return }

        let candidates: [URL]
        do {
            candidates = try FileManager.default.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: [.contentTypeKey], options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants, .skipsPackageDescendants])
        } catch {
            logger.error("Error enumerating PlugIns directory contents: \(error, privacy: .public)")

            return
        }

        var plugins: [String: Any] = [:]

        for candidateURL in candidates {
            guard candidateURL.isAppExtensionBundle else { continue }

            do {
                guard let extensionBundle = Bundle(url: candidateURL) else {
                    throw "Couldn't construct a bundle"
                }

                /// We need the actual registration path for the parent, as it might be inside a bundle container and not the actual
                /// location of the bundle as it was when the `Bundle` was initialized.
                guard let parentRegistrationPath = registration["Path"] as? String else {
                    throw "Parent bundle registration is missing \"Path\""
                }
                let parentURL = URL(fileURLWithPath: parentRegistrationPath)

                if let (extensionID, extensionInfo) = try extensionBundle.pluginKitRegistrationInfo(withParent: self, parentBundleURL: parentURL) {
                    logger.notice("Successfully collected extension info for \(extensionID, privacy: .public): \(extensionInfo, privacy: .public)")

                    plugins[extensionID] = extensionInfo
                }
            } catch {
                logger.error("Error adding extension info to registration for \(candidateURL.lastPathComponent, privacy: .public): \(error, privacy: .public)")
            }
        }

        registration["_LSBundlePlugins"] = plugins
    }
}

private extension URL {
    var isBundle: Bool { (try? resourceValues(forKeys: [.contentTypeKey]))?.contentType?.conforms(to: .bundle) == true }
    var isAppExtensionBundle: Bool { isBundle || lastPathComponent.lowercased() == "appex" }
}
