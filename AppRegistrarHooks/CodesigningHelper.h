@import Foundation;

@interface CodeSigningHelper : NSObject

+ (BOOL)isAdHocSignedBundleAtURL:(NSURL *)bundleURL;
+ (BOOL)isAdHocSignedExecutableAtURL:(NSURL *)executableURL;

@end
