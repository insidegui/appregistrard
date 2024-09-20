#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BSColor: NSObject <NSCopying, NSSecureCoding>

+ (instancetype)colorWithRed:(CGFloat)red
                       green:(CGFloat)green
                        blue:(CGFloat)blue
                       alpha:(CGFloat)alpha;

@property (readonly, nullable) CGColorRef CGColor;

@end

@interface SBSUserNotificationAssetDefinition : NSObject

@end

@interface SBSUserNotificationColorDefinition : NSObject

+ (instancetype _Nullable)definitionWithColorName:(NSString *)name;
+ (instancetype)definitionWithColor:(BSColor *)color;

@end

@interface SBSUserNotificationCAPackageDefinition : SBSUserNotificationAssetDefinition

+ (instancetype)definitionWithCAPackagePath:(NSString *)path;

@end

@interface SBSUserNotificationSystemImageDefinition : SBSUserNotificationAssetDefinition

- (instancetype)initWithSystemImageName:(NSString *)name;
- (instancetype)initWithSystemImageName:(NSString *)name tintColor:(BSColor *)color;

@end

@interface SBSUserNotificationImageAssetDefinition : SBSUserNotificationAssetDefinition

- (instancetype)initWithImagePath:(NSString *)imagePath;
- (instancetype)initWithImageCatalogPath:(NSString *)catalogPath catalogImageKey:(NSString *)imageKey;

@end

@interface SBSUserNotificationSystemApertureContentDefinition : NSObject

@property (nonatomic, copy, nullable) NSString *alertHeader;
@property (nonatomic, copy, nullable) NSString *alertMessage;

@property (nonatomic, copy, nullable) NSString *defaultButtonTitle;
@property (nonatomic, copy, nullable) NSString *alternateButtonTitle;

@property (nonatomic, copy, nullable) SBSUserNotificationColorDefinition *alertHeaderColor;
@property (nonatomic, copy, nullable) NSString *alertHeaderColorName;
@property (nonatomic, copy, nullable) SBSUserNotificationColorDefinition *keyColor;
@property (nonatomic, copy, nullable) NSString *keyColorName;

@property (nonatomic, copy, nullable) SBSUserNotificationAssetDefinition *leadingAssetDefinition;
@property (nonatomic, copy, nullable) SBSUserNotificationAssetDefinition *leadingImageDefinition;

@property (nonatomic, assign) BOOL preventsAutomaticDismissal;
@property (nonatomic, assign) NSTextAlignment alertTextAlignment;

- (id)build;

@end

NS_ASSUME_NONNULL_END
