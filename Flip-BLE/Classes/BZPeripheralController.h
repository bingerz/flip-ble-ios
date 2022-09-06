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

- (void)handleNotifyStateCallback:(CBCharacteristic *)charact error:(NSError *)error;

- (void)handleNotifyValueCallback:(CBCharacteristic *)charact error:(NSError *)error;

- (void)handleIndicateStateCallback:(CBCharacteristic *)charact error:(NSError *)error;

- (void)handleIndicateValueCallback:(CBCharacteristic *)charact error:(NSError *)error;

- (BOOL)readCharact:(ReadCallback)callback;

- (BOOL)writeCharact:(NSData *)value callback:(WriteCallback)callback;

- (BOOL)notifyCharact:(BOOL)enable stateCallback:(NotifyCallback)stateCallback valueCallback:(NotifyCallback)valueCallback;

- (BOOL)indicateCharact:(BOOL)enable stateCallback:(IndicateCallback)stateCallback valueCallback:(IndicateCallback)valueCallback;

@end

#endif /* BZPeripheralController_h */
