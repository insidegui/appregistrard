> Disclaimer: this project is provided for use within the [Apple Security Research Device Program](https://security.apple.com/research-device/), use for any purpose outside of security research is outside the scope of the project, please don't report issues or request features that are not within that scope.

# App Registrar Daemon

A daemon that can be installed to an SRD in order to allow for app installation within research cryptexes.

![screenshot](./screenshot.jpg)

## Requirements

- Security Research Device running iOS 18.0 or later
- [Research SDK](https://github.com/insidegui/researchsdk)

## How Does it Work?

Once installed, `appregistrard` runs as a daemon and:

- Checks the list of cryptexes that are currently installed
- Checks for a `System/Applications` directory within the cryptex mounts
- If found, installs any `.app` bundles found in those cryptexes, so that the apps can be launched from SpringBoard as usual

Additionally, the daemon keeps running in the background and automatically installs any apps found in the `System/Applications` directory
within newly-installed cryptexes, so you can easily have small individual cryptexes for different apps, and `appregistrard` will
automatically make sure those apps are installed when the cryptexes are mounted.

## Build / Install Daemon

You can build a cryptex with `appregistrard` from the Xcode project by building the "cryptex" scheme.

To install, after building the "cryptex" scheme in Xcode, run the provided `install` script, which will find the built root in Xcode's derived data and use `srdtool` to install the cryptex.

Alternatively, download the pre-built cryptex root from [releases](https://github.com/insidegui/appregistrard/releases/latest), extract it and provide the path to the extracted `root` directory as the first argument to the `install` script.

The script configures the `appregistrard` cryptex to persist across reboots. Any cryptexes with apps that are also persisted will have their applications installed by `appregistrard` upon first unlock.

## Customizing Behavior (optional)

Apps inside a cryptex can customize the way they're installed by adding a `ResearchApp` dictionary to their `Info.plist` file.

Currently, `appregistrard` supports the following properties in the `ResearchApp` dictionary:

- `Removable` (BOOL): set to `YES` to allow the app to be deleted by the user like any normal app
- `WantsContainer` (BOOL): set to `YES` for the daemon to create a data container for the app, which also allows app extensions such as widgets to work reliably
- `SystemApp` (BOOL): set to `YES` to install as a system app (requires app to have the `com.apple.private.security.system-application` entitlement)

If no `ResearchApp` dictionary is specified, `Removable` and `WantsContainer` are defaulted to `YES`, so that the app has a container and can be deleted just like any other app. Set these explicitly to `NO` within the `ResearchApp` dictionary to disable this behavior.
