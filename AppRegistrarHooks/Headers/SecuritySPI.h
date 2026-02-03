#pragma clang diagnostic ignored "-Wincomplete-umbrella"

@import Foundation;
@import Security;

#import <TargetConditionals.h>

#if TARGET_OS_IOS

extern const CFStringRef _Nonnull kSecCodeInfoFlags;

typedef CF_OPTIONS(uint32_t, SecCodeSignatureFlags) {
    kSecCodeSignatureAdhoc = 0x0002,
};

typedef CF_OPTIONS(uint32_t, SecCSFlags) {
    kSecCSDefaultFlags = 0,
};

typedef struct CF_BRIDGED_TYPE(id) __SecCode const *SecStaticCodeRef;

OSStatus SecStaticCodeCreateWithPath(CFURLRef __nonnull path, SecCSFlags flags, SecStaticCodeRef * __nonnull CF_RETURNS_RETAINED staticCode);

OSStatus SecCodeCopySigningInformation(SecStaticCodeRef __nonnull code, SecCSFlags flags, CFDictionaryRef * __nonnull CF_RETURNS_RETAINED information);

#endif
