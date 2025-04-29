#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define kMKBFirstUnlockNotification "com.apple.mobile.keybagd.first_unlock"
#define kMKBLockStatusNotification "com.apple.mobile.keybagd.lock_status"

int MKBDeviceUnlockedSinceBoot(void);

typedef NS_ENUM(NSUInteger, MKBDeviceLockState) {
    MKBDeviceLockStateUnlocked = 0,
    MKBDeviceLockStateLocked = 1,
    MKBDeviceLockStateLocking = 2,
    MKBDeviceLockStateKeyBagDisabled = 3,
    MKBDeviceLockStateUnlocking = 4,
    MKBDeviceLockStateGracePeriod = 5,
    MKBDeviceLockStateAssertDelay = 6,
    MKBDeviceLockStateBioUnlock = 6,
};

MKBDeviceLockState MKBGetDeviceLockState(CFDictionaryRef _Nullable options);

NS_ASSUME_NONNULL_END
