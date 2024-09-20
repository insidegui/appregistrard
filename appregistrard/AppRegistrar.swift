import Foundation
import OSLog
import ArgumentParser

let kAppRegistrarSubsystem = "codes.rambo.research.appregistrard"

let logger = Logger(subsystem: kAppRegistrarSubsystem, category: "Daemon")

struct RegistrarOptions: ParsableArguments {
    @Option(help: "The directory within mounted cryptexes where apps can be found.")
    var path: String = "/System/Applications"

    @Option(help: "If specified, apps will be copied into the specified directory before being registered, otherwise they'll be registered at their current location.")
    var copyTo: String?

    @Flag(help: "Treat path as an absolute path instead of a path within the current cryptex. Can be used to register apps that are not inside the cryptex.")
    var absolute = false
}

@main
struct AppRegistrar: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "appregistrard",
        abstract: "The App Registrar Daemon can be run as a daemon so that it registers apps in the /System/Applications folder within mounted cryptexes, or as an on-demand command-line tool for dynamically registering applications with the system.",
        subcommands: [
            AppRegistrarDaemon.self,
            RegisterAppsCommand.self,
            UnregisterAppCommand.self
        ]
    )
}

struct AppRegistrarDaemon: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "daemon",
        abstract: "Runs appregistrard as a daemon, registering any apps found within /System/Applications on mounted cryptexes."
    )

    @OptionGroup
    var options: RegistrarOptions

    func run() throws {
        DaemonServer.shared.activate(applicationsPath: options.path)
    }
}

// MARK: One-off commands

struct RegisterAppsCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "register",
        abstract: "Perform a one-off app registration."
    )

    @OptionGroup
    var options: RegistrarOptions

    func run() throws {
        let registration = AppRegistration(
            sourcePath: options.path,
            sourceIsAbsolutePath: options.absolute,
            destinationPath: options.copyTo
        )
        try registration.run()
    }
}

struct UnregisterAppCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "unregister",
        abstract: "Unregisters a specific app by path."
    )

    @Argument(help: "Absolute path to the app bundle.")
    var path: String

    func run() throws {
        let url = try path.resolvedExistingFileURL(options: [.allowDirectory, .requireDirectory])

        let result = LSApplicationWorkspace.default.unregisterApplication(url)

        if result {
            fputs("Application unregistered!\n", stderr)
        } else {
            fputs("LSApplicationWorkspace failed to unregister the specified app.\n", stderr)
            throw ExitCode(1)
        }
    }
}
