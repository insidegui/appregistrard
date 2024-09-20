#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MIInstallOptions : NSObject

@property (assign) NSUInteger installTargetType;
@property (assign, getter=isUserInitiated) BOOL userInitiated;
@property (assign, getter=isSystemAppInstall) BOOL systemAppInstall;

@end

NS_ASSUME_NONNULL_END
