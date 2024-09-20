#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LSApplicationProxy : NSObject

@property (readonly, getter=isContainerized) BOOL containerized;
@property (readonly) NSString *_Nullable bundleIdentifier;
@property (readonly) NSURL *_Nullable bundleURL;

@end

@interface LSApplicationWorkspace : NSObject

@property (readonly, class) LSApplicationWorkspace *defaultWorkspace;

@property (readonly) NSArray <LSApplicationProxy *> *allInstalledApplications;

- (BOOL)registerApplicationDictionary:(NSDictionary *)dictionary;
- (BOOL)unregisterApplication:(NSURL *)appURL;

@end

NS_ASSUME_NONNULL_END
