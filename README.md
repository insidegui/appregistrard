> Disclaimer: this project is provided for use within the [Apple Security Research Device Program](https://security.apple.com/research-device/), use for any purpose outside of security research is outside the scope of the project, please don't report issues or request features that are not within that scope.

# App Registrar Daemon

A daemon that can be installed to an SRD in order to allow for app installation within research cryptexes.

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

A great way to easily install new apps via cryptexes is by using my [appcryptex](https://github.com/insidegui/appcryptex) template.
Just clone the `appcryptex` repo, cd into it, then run `./install.sh path/to/your/app`. That will package the app as a standalone
cryptex, personalize and install it. Assuming `appregistrard` is running, it will pick that up and register the app with the system,
making its icon appear on SpringBoard.

## Build / Install Daemon

You can build `appregistrard` from source or install the pre-built cryptex from the dmg in the repo's releases page.

There is an aggregate target in the Xcode project that automatically builds/installs appregistrard via `cryptexctl`, but it has only
been tested on my setup so it's possible it won't work for everyone.

## Customizing Behavior (optional)

Apps inside a cryptex can customize the way they're installed by adding a `ResearchApp` dictionary to their `Info.plist` file.

Currently, `appregistrard` supports the following properties in the `ResearchApp` dictionary:

- `Removable` (BOOL): set to `YES` to allow the app to be deleted by the user like any normal app
- `WantsContainer` (BOOL): set to `YES` for the daemon to create a data container for the app, which also allows app extensions such as widgets to work reliably
- `SystemApp` (BOOL): set to `YES` to install as a system app (requires app to have the `com.apple.private.security.system-application` entitlement)

If no `ResearchApp` dictionary is specified, `Removable` and `WantsContainer` are defaulted to `YES`, so that the app has a container and can be deleted just like any other app. Set these explicitly to `NO` within the `ResearchApp` dictionary to disable this behavior.
