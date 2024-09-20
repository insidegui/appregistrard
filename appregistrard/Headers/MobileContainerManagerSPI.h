#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MCMContainer : NSObject

+ (instancetype _Nullable)containerWithIdentifier:(NSString *)identifier
                                createIfNecessary:(BOOL)create
                                          existed:(id _Nullable)existed
                                            error:(NSError **)outError;

@property (readonly) NSURL *_Nullable url;

@end

@interface MCMAppContainer : MCMContainer
@end

@interface MCMPerUserAppContainer : MCMContainer
@end

@interface MCMAppDataContainer : MCMContainer
@end

@interface MCMPluginKitPluginDataContainer : MCMContainer
@end

NS_ASSUME_NONNULL_END
