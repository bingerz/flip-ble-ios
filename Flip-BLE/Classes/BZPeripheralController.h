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

@interface BZPeripheralController : NSObject

- (id)initWithPeripheral:(BZPeripheral *)peripheral;

- (id)withCharact:(CBCharacteristic *)characteristic;

- (id)withUUID:(CBUUID *)serviceUUID charact:(CBUUID *)charactUUID;

- (void)handleReadCallback:(CBCharacteristic *)charact error:(NSError *)error;

- (void)handleNotifyCallback:(CBCharacteristic *)charact error:(NSError *)error;

- (void)handleIndicateCallback:(CBCharacteristic *)charact error:(NSError *)error;

- (BOOL)readCharact:(ReadCallback)callback;

- (BOOL)writeCharact:(NSData *)value callback:(WriteCallback)callback;

- (BOOL)notifyCharact:(BOOL)enable callback:(NotifyCallback)callback;

- (BOOL)indicateCharact:(BOOL)enable callback:(IndicateCallback)callback;

@end

#endif /* BZPeripheralController_h */
