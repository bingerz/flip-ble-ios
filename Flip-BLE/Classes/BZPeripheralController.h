//
//  BZPeripheralController.h
//  Pods
//
//  Created by Hanson on 2022/8/18.
//

#ifndef BZPeripheralController_h
#define BZPeripheralController_h

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "BZPeripheral.h"

NS_ASSUME_NONNULL_BEGIN

@interface BZPeripheralController : NSObject

- (instancetype)initWithPeripheral:(BZPeripheral *)peripheral;

- (nullable instancetype)withCharact:(CBCharacteristic *)characteristic;

- (nullable instancetype)withUUID:(CBUUID *)serviceUUID charact:(CBUUID *)charactUUID;

- (BOOL)readCharact:(ReadCallback)callback;

- (BOOL)writeCharact:(NSData *)value callback:(WriteCallback)callback;

- (BOOL)notifyCharact:(BOOL)enable stateCallback:(NotifyCallback)stateCallback valueCallback:(NotifyCallback)valueCallback;

- (BOOL)indicateCharact:(BOOL)enable stateCallback:(IndicateCallback)stateCallback valueCallback:(IndicateCallback)valueCallback;

@end

NS_ASSUME_NONNULL_END

#endif /* BZPeripheralController_h */
