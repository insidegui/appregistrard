@import Foundation;

#import "AMFIHelper.h"

#import <IOKit/IOKitLib.h>

@implementation AMFIHelper

+ (int)loadTrustCacheFromImage4Data:(NSData *)data
{
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleMobileFileIntegrity"));
    if (!service) {
        fprintf(stderr, "IOServiceGetMatchingService failed.\n");
        return -1;
    }

    kern_return_t err = KERN_SUCCESS;

    io_connect_t connect = 0;
    err = IOServiceOpen(service, mach_task_self(), 0, &connect);
    if (err != KERN_SUCCESS) {
        fprintf(stderr, "IOServiceOpen err %d.\n", err);
        return err;
    }

    err = IOConnectCallMethod(connect, 2, 0, 0, data.bytes, (size_t)data.length, NULL, NULL, NULL, NULL);
    if (err != KERN_SUCCESS) {
        fprintf(stderr, "IOConnectCallMethod err %d.\n", err);
        IOServiceClose(connect);
        return err;
    }

    IOServiceClose(connect);

    return err;
}

@end
