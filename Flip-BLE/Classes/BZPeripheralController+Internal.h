//
//  BZPeripheralController+Internal.h
//  Flip-BLE
//

#ifndef BZPeripheralController_Internal_h
#define BZPeripheralController_Internal_h

#import "BZPeripheralController.h"

NS_ASSUME_NONNULL_BEGIN

@interface BZPeripheralController ()

- (void)handleReadCallback:(nullable CBCharacteristic *)charact error:(nullable NSError *)error;

- (void)handleNotifyStateCallback:(nullable CBCharacteristic *)charact error:(nullable NSError *)error;

- (void)handleNotifyValueCallback:(nullable CBCharacteristic *)charact error:(nullable NSError *)error;

- (void)handleIndicateStateCallback:(nullable CBCharacteristic *)charact error:(nullable NSError *)error;

- (void)handleIndicateValueCallback:(nullable CBCharacteristic *)charact error:(nullable NSError *)error;

@end

NS_ASSUME_NONNULL_END

#endif /* BZPeripheralController_Internal_h */
