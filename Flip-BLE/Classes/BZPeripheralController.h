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
#import "BZBLECallback.h"

@interface BZPeripheralController : NSObject

- (id)initWithPeripheral:(BZPeripheral *)peripheral;

- (id)withCharact:(CBCharacteristic *)characteristic;

- (id)withUUID:(CBUUID *)serviceUUID charact:(CBUUID *)charactUUID;

- (void)handleNotifyCallback:(CBCharacteristic *)charact error:(NSError *)error;

- (void)handleReadCallback:(CBCharacteristic *)charact error:(NSError *)error;

- (BOOL)notifyCharact:(BOOL)enable callback:(NotifyCallback)callback;

- (BOOL)readCharact:(ReadCallback)callback;

- (BOOL)writeCharact:(NSData *)value callback:(WriteCallback)callback;

@end

#endif /* BZPeripheralController_h */
