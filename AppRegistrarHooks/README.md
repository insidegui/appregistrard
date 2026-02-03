# libAppRegistrarHooks

This dynamic library is injected into `installd` on SRD to allow ad-hoc binaries to pass its code signature validation checks.

With this library injected, `appregistrard` can use the InstallCoordination-based installation method, which installs
apps exactly the same way as those installed via Xcode or the App Store, ensuring that all app extension types work as expected.

The daemon will automatically set up injection by copying this dylib into a place that `installd` can load from
and setting the `DYLD_INSERT_LIBRARIES` environment via `launchd` to include it. The library does nothing unless loaded into `installd`.
