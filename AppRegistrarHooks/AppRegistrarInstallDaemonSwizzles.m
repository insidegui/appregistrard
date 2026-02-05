#import "AppRegistrarInstallDaemonSwizzles.h"

#import "CodesigningHelper.h"

#import "installd.h"
#import "InstalledContentLibrary.h"

#import "SwizzlingHelper.h"

#import "AppRegistrarHooks-Swift.h"

@import os.log;

os_log_t logger(void)
{
    static dispatch_once_t onceToken;
    static os_log_t _log;
    dispatch_once(&onceToken, ^{
        _log = os_log_create("codes.rambo.research.appregistrard", "AppRegistrarInstallDaemonSwizzles");
    });
    return _log;
}

/// Declarations for things we'll need from the runtime.
@interface NSObject ()

@property (readonly) BOOL isPlaceholderInstall;
@property (strong) MIExecutableBundle *bundle;
@property (strong) MICodeSigningInfo *bundleSigningInfo;

- (BOOL)__original_performVerificationWithError:(NSError *__autoreleasing *)outError;

@end

@implementation AppRegistrarInstallDaemonSwizzles

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (strcmp(getprogname(), "installd")) return;

        os_log_debug(logger(), "🚀 Loaded into installd, hooking!");

        SwizzleInstanceMethod(MIInstallableBundle, performVerificationWithError:, AppRegistrarInstallDaemonSwizzles);
        SwizzleInstanceMethod(MIDaemonConfiguration, codeSigningEnforcementIsDisabled, AppRegistrarInstallDaemonSwizzles);
    });
}

/**
 This is the swizzle for the method that verifies the code signature and certain special entitlements on bundles being installed.

 It used to be done in `MICodeSigningVerifier` before iOS 18.4, but since then this method in `MIInstallableBundle`
 is what does the heavy lifting and `MICodeSigningVerifier` has lost a lot of its importance.

 Since this cryptex technically only supports iOS 26+, only this override is left, and it has been reimplemented
 to completely fake the verification by extracting the code signature information using the most lenient validation possible,
 which skips a bunch of the special entitlement checks performed by the original implementation.

 The most important step is actually setting `bundleSigningInfo` on the `MIInstallableBundle` to the signing info
 extracted from `MIExecutableBundle` by calling `codeSigningInfoByValidatingResources:...`.

 The presence of that signing info and the return value of `YES` is what concludes the verification successfully.

 Of course none of that would work before first performing the TSS signing and trust cache load for all executables present within the bundle,
 but even then the original implementation has some annoying validations that are skipped by doing the above.

 To get ad-hoc binaries to pass validation, it's also crucial to override `-[MIDaemonConfiguration codeSigningEnforcementIsDisabled]` so that it returns `YES`, which this class also does.
 */
- (BOOL)__override_performVerificationWithError:(NSError *__autoreleasing *)outError
{
    os_log_t log = logger();

    BOOL isPlaceholder = self.isPlaceholderInstall;
    NSString *logFunctionName = [NSString stringWithFormat:@"%@%@", NSStringFromSelector(_cmd), (isPlaceholder ? @"[placeholder bundle]" : @"")];

    MIExecutableBundle *bundle = self.bundle;

    os_log(log, "%{public}@ called with bundle %@", logFunctionName, self.bundle);

    NSError *myError;
    BOOL result;

    if (isPlaceholder) {
        os_log_debug(log, "Bundle is placeholder install, delegating to original performVerificationWithError implementation");
        result = [self __original_performVerificationWithError:&myError];
    } else {
        os_log_debug(log, "Bundle is real install, will perform lenient verification.");

        NSString *bundleName = bundle.bundleURL.lastPathComponent;

        os_log_debug(log, "Checking if %@ is adhoc-signed...", bundleName);

        BOOL isAdHoc = [CodeSigningHelper isAdHocSignedBundleAtURL:bundle.bundleURL];

        if (!isAdHoc) {
            os_log(log, "%@ is not adhoc-signed, proceeding with regular installd flow...", bundleName);
            return [self __original_performVerificationWithError:outError];
        }

        NSURL *trustCacheURL = [bundle.bundleURL URLByAppendingPathComponent:@"trustcache.img4"];

        TrustCacheFSRequest *request;

        if ([NSFileManager.defaultManager fileExistsAtPath:trustCacheURL.path]) {
            os_log(log, "Found trust cache for %{public}@, requesting load...", bundleName);

            request = [[TrustCacheFSRequest alloc] initWithAction:TrustCacheFSRequestActionLoad bundleURL:bundle.bundleURL trustCacheURL:trustCacheURL];
        } else {
            os_log(log, "No trust cache found, performing full chain for %@...", bundleName);

            request = [[TrustCacheFSRequest alloc] initWithAction:TrustCacheFSRequestActionFullChain bundleURL:bundle.bundleURL trustCacheURL:nil];
        }

        NSError *trustCacheError;
        if ([request performAndWaitSyncAndReturnError:&trustCacheError]) {
            os_log(log, "Successfully performed full chain trust cache process for %@", bundleName);
        } else {
            os_log_error(log, "Error performing full chain trust cache process for %@. %{public}@", bundleName, trustCacheError);

            *outError = trustCacheError;
            return NO;
        }

        if (!bundle) {
            os_log_fault(log, "MIInstallableBundle has no bundle!");
            myError = [NSError errorWithDomain:@"codes.rambo.appregistrard" code:0 userInfo:@{NSLocalizedFailureReasonErrorKey: @"MIInstallableBundle has no bundle."}];
            result = NO;
        } else {
            /// Create signing info with most lenient validation possible.
            /// Regular verification by original implementation would work for most cases, but doing this allows us to skip some annoying checks
            /// such as checks for forbidden entitlement combinations that are only checked during installation.
            MICodeSigningInfo *signingInfo = [bundle codeSigningInfoByValidatingResources:NO
                                                            performingOnlineAuthorization:NO
                                                                ignoringCachedSigningInfo:NO
                                                           checkingTrustCacheIfApplicable:NO
                                                              skippingProfileIDValidation:YES
                                                                                    error:&myError];

            /// This is the crucial step: we must set the signing info on the installable bundle,
            /// otherwise installation will fail even if we return a success response from this method.
            self.bundleSigningInfo = signingInfo;

            if (signingInfo) {
                os_log(log, "Successfully obtained signing info for bundle - %{public}@", signingInfo.dictionaryRepresentation);
                result = YES;
            } else {
                os_log_error(log, "Error obtaining signing info for bundle - %{public}@", myError);
                result = NO;
            }
        }
    }

    if (result) {
        os_log(log, "%{public}@ OK", logFunctionName);
        return YES;
    } else {
        os_log_error(log, "%{public}@ FAILED: %{public}@", logFunctionName, myError);
        if (outError) *outError = myError;
        return NO;
    }
}

/// This override is on `MIDaemonConfiguration`, it's required so that ad-hoc signed binaries are accepted.
- (BOOL)__override_codeSigningEnforcementIsDisabled
{
    return YES;
}

@end
