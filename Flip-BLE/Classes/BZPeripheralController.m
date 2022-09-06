//
//  BZPeripheralController.m
//  Flip-BLE
//
//  Created by Hanson on 2022/8/18.
//

#import <Foundation/Foundation.h>
#import "BZBLEError.h"
#import "BZPeripheralController.h"

@interface BZPeripheralController ()

@property (nonatomic, assign) BZPeripheral *peripheral;
@property (nonatomic, assign) CBPeripheral *blePeripheral;
@property (nonatomic, assign) CBService *service;
@property (nonatomic, assign) CBCharacteristic *characteristic;

@end

@implementation BZPeripheralController

- (id)initWithPeripheral:(BZPeripheral *)peripheral{
    self = [super init];
    if (self) {
        _peripheral = peripheral;
        _blePeripheral = _peripheral.blePeripheral;
    }
    return self;
}

- (id)withCharact:(CBCharacteristic *)characteristic{
    if (_blePeripheral && characteristic) {
        _service = characteristic.service;
        _characteristic = characteristic;
        return self;
    }
    return nil;
}

- (id)withUUID:(CBUUID *)serviceUUID charact:(CBUUID *)charactUUID{
    if (_blePeripheral && serviceUUID != nil) {
        NSArray *services = [_blePeripheral services];
        for (CBService *s in services) {
            if ([[s UUID] isEqual:serviceUUID]) {
                _service = s;
                break;
            }
        }
        if (_service != nil) {
            NSArray *charactrisitics = [_service characteristics];
            if ([charactrisitics count]) {
                for (CBCharacteristic *c in charactrisitics) {
                    if ([[c UUID] isEqual:charactUUID]) {
                        _characteristic = c;
                        break;
                    }
                }
            }
        }
        return self;
    }
    return nil;
}

- (void)addReadCallback:(ReadCallback)callback{
    NSMutableDictionary *readBlocks = [_peripheral readBlocks];
    NSMutableDictionary *characteristics = readBlocks[_service.UUID];
    if (!characteristics) {
        characteristics = [NSMutableDictionary dictionaryWithCapacity:1];
        readBlocks[_service.UUID] = characteristics;
    }
    NSMutableArray *callbacks = characteristics[_characteristic.UUID];
    if (!callbacks) {
        callbacks = [NSMutableArray arrayWithCapacity:1];
        characteristics[_characteristic.UUID] = callbacks;
    }
    [callbacks addObject:[callback copy]];
}

- (void)handleReadCallback:(CBCharacteristic *)charact error:(NSError *)error{
    NSMutableDictionary *readBlocks = [_peripheral readBlocks];
    NSDictionary *characteristics = readBlocks[charact.service.UUID];
    if (characteristics) {
        NSMutableArray *array = characteristics[charact.UUID];
        if (array.count > 0) {
            for (ReadCallback block in array) {
                block(charact, error);
            }
            [array removeAllObjects];
        }
    }
}

- (void)addNotifyStateCallback:(NotifyCallback)callback{
    NSMutableDictionary *notifyStateBlocks = [_peripheral notifyStateBlocks];
    NSMutableDictionary *characteristics = notifyStateBlocks[_service.UUID];
    if (!characteristics) {
        characteristics = [NSMutableDictionary dictionaryWithCapacity:1];
        notifyStateBlocks[_service.UUID] = characteristics;
    }
    NSMutableArray *callbacks = characteristics[_characteristic.UUID];
    if (!callbacks) {
        callbacks = [NSMutableArray arrayWithCapacity:1];
        characteristics[_characteristic.UUID] = callbacks;
    }
    [callbacks addObject:[callback copy]];
}

- (void)removeNotifyStateCallback{
    NSMutableDictionary *notifyStateBlocks = [_peripheral notifyStateBlocks];
    NSMutableDictionary *characteristics = notifyStateBlocks[_service.UUID];
    if (!characteristics) {
        characteristics = [NSMutableDictionary dictionaryWithCapacity:1];
        notifyStateBlocks[_service.UUID] = characteristics;
    }
    NSMutableArray *callbacks = characteristics[_characteristic.UUID];
    if (callbacks) {
        [callbacks removeAllObjects];
    }
}

- (void)handleNotifyStateCallback:(CBCharacteristic *)charact error:(NSError *)error{
    NSMutableDictionary *notifyStateBlocks = [_peripheral notifyStateBlocks];
    NSDictionary *characteristics = notifyStateBlocks[charact.service.UUID];
    if (characteristics) {
        NSMutableArray *array = characteristics[charact.UUID];
        if (array.count > 0) {
            for (NotifyCallback callback in array) {
                callback(charact, error);
            }
        }
    }
}

- (void)addNotifyValueCallback:(NotifyCallback)callback{
    NSMutableDictionary *notifyValueBlocks = [_peripheral notifyValueBlocks];
    NSMutableDictionary *characteristics = notifyValueBlocks[_service.UUID];
    if (!characteristics) {
        characteristics = [NSMutableDictionary dictionaryWithCapacity:1];
        notifyValueBlocks[_service.UUID] = characteristics;
    }
    NSMutableArray *callbacks = characteristics[_characteristic.UUID];
    if (!callbacks) {
        callbacks = [NSMutableArray arrayWithCapacity:1];
        characteristics[_characteristic.UUID] = callbacks;
    }
    [callbacks addObject:[callback copy]];
}

- (void)removeNotifyValueCallback{
    NSMutableDictionary *notifyValueBlocks = [_peripheral notifyValueBlocks];
    NSMutableDictionary *characteristics = notifyValueBlocks[_service.UUID];
    if (!characteristics) {
        characteristics = [NSMutableDictionary dictionaryWithCapacity:1];
        notifyValueBlocks[_service.UUID] = characteristics;
    }
    NSMutableArray *callbacks = characteristics[_characteristic.UUID];
    if (callbacks) {
        [callbacks removeAllObjects];
    }
}

- (void)handleNotifyValueCallback:(CBCharacteristic *)charact error:(NSError *)error{
    NSMutableDictionary *notifyValueBlocks = [_peripheral notifyValueBlocks];
    NSDictionary *characteristics = notifyValueBlocks[charact.service.UUID];
    if (characteristics) {
        NSMutableArray *array = characteristics[charact.UUID];
        if (array.count > 0) {
            for (NotifyCallback callback in array) {
                callback(charact, error);
            }
        }
    }
}

- (void)addIndicateStateCallback:(IndicateCallback)callback{
    NSMutableDictionary *indicateStateBlocks = [_peripheral indicateStateBlocks];
    NSMutableDictionary *characteristics = indicateStateBlocks[_service.UUID];
    if (!characteristics) {
        characteristics = [NSMutableDictionary dictionaryWithCapacity:1];
        indicateStateBlocks[_service.UUID] = characteristics;
    }
    NSMutableArray *callbacks = characteristics[_characteristic.UUID];
    if (!callbacks) {
        callbacks = [NSMutableArray arrayWithCapacity:1];
        characteristics[_characteristic.UUID] = callbacks;
    }
    [callbacks addObject:[callback copy]];
}

- (void)removeIndicateStateCallback{
    NSMutableDictionary *indicateStateBlocks = [_peripheral indicateStateBlocks];
    NSMutableDictionary *characteristics = indicateStateBlocks[_service.UUID];
    if (!characteristics) {
        characteristics = [NSMutableDictionary dictionaryWithCapacity:1];
        indicateStateBlocks[_service.UUID] = characteristics;
    }
    NSMutableArray *callbacks = characteristics[_characteristic.UUID];
    if (callbacks) {
        [callbacks removeAllObjects];
    }
}

- (void)handleIndicateStateCallback:(CBCharacteristic *)charact error:(NSError *)error{
    NSMutableDictionary *indicateStateBlocks = [_peripheral indicateStateBlocks];
    NSDictionary *characteristics = indicateStateBlocks[charact.service.UUID];
    if (characteristics) {
        NSMutableArray *array = characteristics[charact.UUID];
        if (array.count > 0) {
            for (IndicateCallback callback in array) {
                callback(charact, error);
            }
        }
    }
}

- (void)addIndicateValueCallback:(IndicateCallback)callback{
    NSMutableDictionary *indicateValueBlocks = [_peripheral indicateValueBlocks];
    NSMutableDictionary *characteristics = indicateValueBlocks[_service.UUID];
    if (!characteristics) {
        characteristics = [NSMutableDictionary dictionaryWithCapacity:1];
        indicateValueBlocks[_service.UUID] = characteristics;
    }
    NSMutableArray *callbacks = characteristics[_characteristic.UUID];
    if (!callbacks) {
        callbacks = [NSMutableArray arrayWithCapacity:1];
        characteristics[_characteristic.UUID] = callbacks;
    }
    [callbacks addObject:[callback copy]];
}

- (void)removeIndicateValueCallback{
    NSMutableDictionary *indicateValueBlocks = [_peripheral indicateValueBlocks];
    NSMutableDictionary *characteristics = indicateValueBlocks[_service.UUID];
    if (!characteristics) {
        characteristics = [NSMutableDictionary dictionaryWithCapacity:1];
        indicateValueBlocks[_service.UUID] = characteristics;
    }
    NSMutableArray *callbacks = characteristics[_characteristic.UUID];
    if (callbacks) {
        [callbacks removeAllObjects];
    }
}

- (void)handleIndicateValueCallback:(CBCharacteristic *)charact error:(NSError *)error{
    NSMutableDictionary *indicateValueBlocks = [_peripheral indicateValueBlocks];
    NSDictionary *characteristics = indicateValueBlocks[charact.service.UUID];
    if (characteristics) {
        NSMutableArray *array = characteristics[charact.UUID];
        if (array.count > 0) {
            for (IndicateCallback callback in array) {
                callback(charact, error);
            }
        }
    }
}

- (BOOL)readCharact:(ReadCallback)callback{
    if (!callback) {
        NSLog(@"Read failure, callback is null");
        return NO;
    }
    
    if (_blePeripheral && _characteristic) {
        if (_characteristic.properties & CBCharacteristicPropertyRead) {
            [self addReadCallback:callback];
            [_blePeripheral readValueForCharacteristic:_characteristic];
            return YES;
        } else {
            if (callback) {
                NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                          @"Read characteristic fail", NSLocalizedDescriptionKey,
                                          @"Reason:Characteristic not support read", NSLocalizedFailureReasonErrorKey, nil];
                NSError *error = [NTBLEError errorCode:ErrorCodeOther userInfo:userInfo];
                callback(_characteristic, error);
            }
        }
    } else {
        if (callback) {
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      @"Read characteristic fail", NSLocalizedDescriptionKey,
                                      @"Reason:Characteristic is null", NSLocalizedFailureReasonErrorKey, nil];
            NSError *error = [NTBLEError errorCode:ErrorCodeOther userInfo:userInfo];
            callback(_characteristic, error);
        }
    }
    return NO;
}

- (BOOL)writeCharact:(NSData *)value callback:(WriteCallback)callback{
    if (!callback) {
        NSLog(@"Write failure, callback is null");
        return NO;
    }
    if (_blePeripheral && _characteristic) {
        if (_characteristic.properties & CBCharacteristicPropertyWrite ||
            _characteristic.properties & CBCharacteristicPropertyWriteWithoutResponse) {
            CBCharacteristicWriteType writeType = _characteristic.properties & CBCharacteristicPropertyWrite ? CBCharacteristicWriteWithResponse : CBCharacteristicWriteWithoutResponse;
            [_blePeripheral writeValue:value forCharacteristic:_characteristic type:writeType];
            if (callback) {
                callback(_characteristic, nil);
            }
            return YES;
        } else {
            if (callback) {
                NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                          @"Write characteristic fail", NSLocalizedDescriptionKey,
                                          @"Reason:Characteristic not support write", NSLocalizedFailureReasonErrorKey, nil];
                NSError *error = [NTBLEError errorCode:ErrorCodeOther userInfo:userInfo];
                callback(_characteristic, error);
            }
        }
    } else {
        if (callback) {
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      @"Write characteristic fail", NSLocalizedDescriptionKey,
                                      @"Reason:Characteristic is null", NSLocalizedFailureReasonErrorKey, nil];
            NSError *error = [NTBLEError errorCode:ErrorCodeOther userInfo:userInfo];
            callback(_characteristic, error);
        }
    }
    return NO;
}

- (BOOL)notifyCharact:(BOOL)enable stateCallback:(NotifyCallback)stateCallback valueCallback:(NotifyCallback)valueCallback{
    if (!stateCallback || !valueCallback) {
        NSLog(@"Notify failure, callback is null");
        return NO;
    }
    
    if (_blePeripheral && _characteristic) {
        if (_characteristic.properties & CBCharacteristicPropertyNotify) {
            if (enable) {
                [self addNotifyStateCallback:stateCallback];
                [self addNotifyValueCallback:valueCallback];
            } else {
                [self removeNotifyStateCallback];
                [self removeNotifyValueCallback];
            }
            if (enable ^ _characteristic.isNotifying) {
                [_blePeripheral setNotifyValue:enable forCharacteristic:_characteristic];
            }
            return YES;
        } else {
            if (stateCallback) {
                NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                          @"Notify characteristic fail", NSLocalizedDescriptionKey,
                                          @"Reason:Characteristic not support notify", NSLocalizedFailureReasonErrorKey, nil];
                NSError *error = [NTBLEError errorCode:ErrorCodeOther userInfo:userInfo];
                stateCallback(_characteristic, error);
            }
        }
    } else {
        if (stateCallback) {
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      @"Notify characteristic fail", NSLocalizedDescriptionKey,
                                      @"Reason:Characteristic is null", NSLocalizedFailureReasonErrorKey, nil];
            NSError *error = [NTBLEError errorCode:ErrorCodeOther userInfo:userInfo];
            stateCallback(_characteristic, error);
        }
    }
    return NO;
}

- (BOOL)indicateCharact:(BOOL)enable stateCallback:(IndicateCallback)stateCallback valueCallback:(IndicateCallback)valueCallback{
    if (!stateCallback || !valueCallback) {
        NSLog(@"Indicate failure, callback is null");
        return NO;
    }
    
    if (_blePeripheral && _characteristic) {
        if (_characteristic.properties & CBCharacteristicPropertyIndicate) {
            if (enable) {
                [self addIndicateStateCallback:stateCallback];
                [self addIndicateValueCallback:valueCallback];
            } else {
                [self removeIndicateStateCallback];
                [self removeIndicateValueCallback];
            }
            if (enable ^ _characteristic.isNotifying) {
                [_blePeripheral setNotifyValue:enable forCharacteristic:_characteristic];
            }
            return YES;
        } else {
            if (stateCallback) {
                NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                          @"Indicate characteristic fail", NSLocalizedDescriptionKey,
                                          @"Reason:Characteristic not support indicate", NSLocalizedFailureReasonErrorKey, nil];
                NSError *error = [NTBLEError errorCode:ErrorCodeOther userInfo:userInfo];
                stateCallback(_characteristic, error);
            }
        }
    } else {
        if (stateCallback) {
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      @"Indicate characteristic fail", NSLocalizedDescriptionKey,
                                      @"Reason:Characteristic is null", NSLocalizedFailureReasonErrorKey, nil];
            NSError *error = [NTBLEError errorCode:ErrorCodeOther userInfo:userInfo];
            stateCallback(_characteristic, error);
        }
    }
    return NO;
}

@end
