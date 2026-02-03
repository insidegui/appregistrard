@import Foundation;

@class MIExecutableBundle, MICodeSigningInfo;

@interface MIInstallable : NSObject

- (BOOL)performVerificationWithError:(NSError **)outError;

@end

@interface MIInstallableBundle : MIInstallable

@property (readonly) MIExecutableBundle *bundle;
@property (readonly) BOOL isPlaceholderInstall;
@property (strong) MICodeSigningInfo *bundleSigningInfo;

@end
