@import Foundation;

NS_ASSUME_NONNULL_BEGIN

#define SwizzleInstanceMethod( className, methodName, overridingType ) \
[SwizzlingHelper swizzleClass:NSClassFromString(@#className) method:NSSelectorFromString(@#methodName) overridingClass:[overridingType class] isClassMethod:NO];

#define SwizzleClassMethod( className, methodName, overridingType ) \
[SwizzlingHelper swizzleClass:NSClassFromString(@#className) method:NSSelectorFromString(@#methodName) overridingClass:[overridingType class] isClassMethod:YES];

@interface SwizzlingHelper : NSObject

/// Swizzles the method on the provided class with an instance method named
/// according to the pattern in the override class.
/// The pattern is as follows:
/// Let's say the original selector is `removeObjectAtIndex:`
/// The override class should have a method with the selector `__override_removeObjectAtIndex:`
/// Swizzling also introduces the original method's implementation that can be called from the override,
/// in this example it would be `__original_removeObjectAtIndex:`.
/// The override and original methods will be either instance or class methods depending upon the `isClassMethod` argument.
+ (BOOL)swizzleClass:(Class)aClass
              method:(SEL)methodSelector
     overridingClass:(Class)overrideClass
       isClassMethod:(BOOL)isClassMethod;

@end

NS_ASSUME_NONNULL_END
