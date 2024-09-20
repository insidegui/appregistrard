#import <CoreFoundation/CoreFoundation.h>

#import <dlfcn.h>

CFUserNotificationRef soft_CFUserNotificationCreate(CFAllocatorRef allocator, CFTimeInterval timeout, CFOptionFlags flags, SInt32 *error, CFDictionaryRef dictionary)
{
    void *handle = dlopen("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation", RTLD_NOW);
    void *sym = dlsym(handle, "CFUserNotificationCreate");

    typedef CFUserNotificationRef (*func_ptr_t)(CFAllocatorRef, CFTimeInterval, CFOptionFlags, SInt32*, CFDictionaryRef);
    func_ptr_t callIt = (func_ptr_t)sym;

    return callIt(allocator, timeout, flags, error, dictionary);
}

CFRunLoopSourceRef soft_CFUserNotificationCreateRunLoopSource(CFAllocatorRef allocator, CFUserNotificationRef userNotification, CFUserNotificationCallBack callout, CFIndex order)
{
    void *handle = dlopen("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation", RTLD_NOW);
    void *sym = dlsym(handle, "CFUserNotificationCreateRunLoopSource");

    typedef CFRunLoopSourceRef (*func_ptr_t)(CFAllocatorRef, CFUserNotificationRef, CFUserNotificationCallBack, CFIndex);
    func_ptr_t callIt = (func_ptr_t)sym;

    return callIt(allocator, userNotification, callout, order);
}
