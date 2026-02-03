@import Foundation;

@interface MIBundle : NSObject

@property (readonly) NSURL *bundleURL;
@property (readonly) NSString *identifier;
@property (readonly) BOOL isPlaceholder;

@end

@interface MIExecutableBundle : MIBundle

@property (readonly) NSURL *executableURL;

- (MICodeSigningInfo *)codeSigningInfoByValidatingResources:(BOOL)resources
                              performingOnlineAuthorization:(BOOL)authorization
                                  ignoringCachedSigningInfo:(BOOL)info
                             checkingTrustCacheIfApplicable:(BOOL)applicable
                                skippingProfileIDValidation:(BOOL)idvalidation
                                                      error:(NSError **)outError;

@end

@interface MIDaemonConfiguration : NSObject

- (BOOL)codeSigningEnforcementIsDisabled;

@end

@interface MICodeSigningInfo : NSObject

@property (readonly, copy, nonatomic) NSDictionary *dictionaryRepresentation;

@end
