#import "CodesigningHelper.h"

@import os.log;

#import "SecuritySPI.h"

os_log_t csLogger(void)
{
    static dispatch_once_t onceToken;
    static os_log_t _log;
    dispatch_once(&onceToken, ^{
        _log = os_log_create("codes.rambo.research.appregistrard", "CodeSigningHelper");
    });
    return _log;
}

@implementation CodeSigningHelper

+ (BOOL)isAdHocSignedBundleAtURL:(NSURL *)bundleURL
{
    os_log_t log = csLogger();

    os_log_debug(log, "Checking adhoc status for bundle: %@", bundleURL.lastPathComponent);

    NSBundle *bundle = [NSBundle bundleWithURL:bundleURL];
    if (!bundle) {
        os_log_error(log, "Failed to construct NSBundle with bundle at %@", bundleURL.path);
        return NO;
    }

    NSURL *effectiveExecutableURL = nil;
    if (bundle.executableURL) {
        effectiveExecutableURL = bundle.executableURL;
    } else {
        effectiveExecutableURL = [bundleURL URLByAppendingPathComponent:bundleURL.URLByDeletingPathExtension.lastPathComponent];
        os_log_error(log, "[WARN] Bundle has no executable URL, using default: %@", effectiveExecutableURL.path);
    }

    return [self isAdHocSignedExecutableAtURL:effectiveExecutableURL];
}

+ (BOOL)isAdHocSignedExecutableAtURL:(NSURL *)executableURL
{
    os_log_t log = csLogger();

    NSString *name = executableURL.lastPathComponent;

    os_log_debug(log, "Checking adhoc status for executable: %@", executableURL.lastPathComponent);

    SecStaticCodeRef code;
    OSStatus status = SecStaticCodeCreateWithPath((__bridge CFURLRef)executableURL, kSecCSDefaultFlags, &code);
    if (status != errSecSuccess) {
        os_log_error(log, "SecStaticCodeCreateWithPath failed with %{public}d (%{public}@)", status, SecCopyErrorMessageString(status, NULL));
        return NO;
    }

    os_log_debug(log, "Successfully obtained static code reference for %@", name);

    CFDictionaryRef signingInfo;
    status = SecCodeCopySigningInformation(code, kSecCSDefaultFlags, &signingInfo);
    if (status != errSecSuccess) {
        os_log_error(log, "SecCodeCopySigningInformation failed with %{public}d (%{public}@)", status, SecCopyErrorMessageString(status, NULL));
        return NO;
    }

    os_log_debug(log, "Successfully obtained signing info for %@", name);

    NSDictionary <NSString *, id> *infoDict = (__bridge NSDictionary *)signingInfo;
    NSNumber *flags = infoDict[(__bridge NSString *)kSecCodeInfoFlags];
    if (!flags) {
        os_log_error(log, "Signing info for %@ is missing kSecCodeInfoFlags", name);
        return NO;
    }

    BOOL isAdHoc = (flags.unsignedIntValue & kSecCodeSignatureAdhoc) != 0;

    os_log(log, "%@ is adhoc? %{public}@", name, ((isAdHoc) ? @"YES" : @"NO"));

    return isAdHoc;
}

@end
