@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface IXAppInstallCoordinator : NSObject

+ (void)installApplication:(NSURL *)applicationURL
    forPersonaUniqueString:(NSString *)personaUniqueString
             consumeSource:(BOOL)consumeSource
                   options:(nullable NSDictionary *)options
                completion:(nullable void(^)(void))completion;

@end

NS_ASSUME_NONNULL_END
