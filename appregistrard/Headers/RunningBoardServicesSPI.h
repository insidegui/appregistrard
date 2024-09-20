#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RBSProcessPredicate: NSObject
+ (instancetype)predicateMatchingBundleIdentifier:(NSString *)bundleID;
@end

@interface RBSTerminateContext : NSObject
+ (instancetype)defaultContextWithExplanation:(NSString *)explanation;
@end

@interface RBSRequest : NSObject
@end

@interface RBSTerminateRequest : RBSRequest

@property (nonatomic, readonly) BOOL targetsAllManagedProcesses;
@property (nonatomic, strong) RBSProcessPredicate *predicate;
@property (nonatomic, strong) RBSProcessPredicate *allow;
@property (nonatomic, readonly) RBSTerminateContext *context;

- (instancetype)initWithPredicate:(RBSProcessPredicate *)predicate context:(RBSTerminateContext *)context;

- (BOOL)execute:(NSError **)outError;

@end

NS_ASSUME_NONNULL_END
