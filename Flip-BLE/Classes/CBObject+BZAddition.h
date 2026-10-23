//
//  CBObject+BZAddition.h
//  Flip-BLE
//
//  Created by Hanson on 2022/8/18.
//

#ifndef CBObject_BZAddition_h
#define CBObject_BZAddition_h

#import <CoreBluetooth/CoreBluetooth.h>

NS_ASSUME_NONNULL_BEGIN

@interface CBPeripheral (UUIDString)
- (nullable NSString *)UUIDString;
@end

@interface CBService (UUIDString)
- (NSString *)UUIDString;
@end

@interface CBCharacteristic (UUIDString)
- (NSString *)UUIDString;
@end

@interface CBDescriptor (UUIDString)
- (NSString *)UUIDString;
@end

@interface CBUUID (UUIDString)
- (NSString *)UUIDString;

@end

NS_ASSUME_NONNULL_END

#endif /* CBObject_BZAddition_h */
