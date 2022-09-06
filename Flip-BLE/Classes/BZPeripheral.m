//
//  BZPeripheral.m
//  Flip-BLE
//
//  Created by Hanson on 2022/8/18.
//

#import <Foundation/Foundation.h>
#import "BZCentralManager.h"
#import "CBObject+BZAddition.h"
#import "BZBLEError.h"
#import "BZPeripheralController.h"
#import "BZMultiplePeripheralController.h"
#import "BZPeripheral.h"

@implementation BZPeripheral {
    
    CBPeripheral *_blePeripheral;
    
    BZPeripheralState _state;   //NTPeripheral state machine.
    
    //NSLock *discoverLock;       //handle discover all service lock.
    BOOL _isDiscoverServiceAll; //NTPeripheral handle discover all service character descriptor.
    NSUInteger _discoverServiceCount;   //discover all service count.
    
    NSMutableArray      *_discoverCallbacks;
    NSMutableArray      *_serviceCallbacks;
    NSMutableDictionary *_charactCallbacks;
    
    NSMutableArray      *_rssiCallbacks;
    NSMutableDictionary *_readCallbacks;
    NSMutableDictionary *_writeCallbacks;
    NSMutableDictionary *_notifyStateCallbacks;
    NSMutableDictionary *_notifyValueCallbacks;
    NSMutableDictionary *_indicateStateCallbacks;
    NSMutableDictionary *_indicateValueCallbacks;
}

- (id)initWithPeripheral:(CBPeripheral *)blePeripheral{
    self = [super init];
    if (self) {
        _blePeripheral = blePeripheral;
        _blePeripheral.delegate = self;
        _state = BZPeripheralStateDisconnected;
    }
    return self;
}

- (void)dealloc{
    //[discoverLock unlock];
    //discoverLock = nil;
    [self cleanCallbacks];
    if (_blePeripheral) {
        _blePeripheral.delegate = nil;
        _blePeripheral = nil;
        _state = BZPeripheralStateDisconnected;
    }
}

#pragma mark - Peripheral property

- (CBPeripheral *)blePeripheral{
    return _blePeripheral;
}

- (NSString *)bleState{
    NSString *stateStr = @"UNKnown";
    if (_blePeripheral) {
        switch (_blePeripheral.state) {
            case CBPeripheralStateDisconnected:
                stateStr = @"Disconnected";
                break;
            case CBPeripheralStateConnecting:
                stateStr = @"Connecting";
                break;
            case CBPeripheralStateConnected:
                stateStr = @"Connected";
                break;
            case CBPeripheralStateDisconnecting:
                stateStr = @"Disconnecting";
                break;
            default:
                break;
        }
    }
    return stateStr;
}

- (NSString *)name{
    if (_blePeripheral) {
        return _blePeripheral.name;
    }
    return nil;
}

- (NSString *)UUIDString{
    if (_blePeripheral && _blePeripheral.identifier) {
        return [_blePeripheral.identifier UUIDString];
    }
    return nil;
}

- (NSArray<CBService *> *)services{
    return _blePeripheral ? _blePeripheral.services : nil;
}

- (BOOL)isConnecting{
    return _blePeripheral && _blePeripheral.state == CBPeripheralStateConnecting;
}

- (BOOL)isConnected{
    return _blePeripheral && _blePeripheral.state == CBPeripheralStateConnected;
}

- (void)updateBLEPeripheral:(CBPeripheral *)blePeripheral{
    if (blePeripheral) {
        _blePeripheral = blePeripheral;
        _blePeripheral.delegate = self;
    }
}

- (void)updateStateWithBLEPeripheral:(CBPeripheral *)blePeripheral{
    if (blePeripheral) {
        switch (blePeripheral.state) {
            case CBPeripheralStateDisconnected:
                _state = BZPeripheralStateDisconnected;
                break;
                
            case CBPeripheralStateConnecting:
                _state = BZPeripheralStateConnecting;
                break;
                
            case CBPeripheralStateConnected:
                if (_state != BZPeripheralStateDiscovering) {
                    //Prevent multiple connections from disrupting the discovery service process
                    _state = BZPeripheralStateConnected;
                }
                break;
                
            default:
                _state = BZPeripheralStateDisconnected;
                break;
        }
    }
}

#pragma mark - Peripheral utils

- (CBUUID *)formUUID:(NSString *)uuidString{
    return [CBUUID UUIDWithString:uuidString];
}

#pragma mark - Peripheral block

- (NSMutableArray *)discoverBlocks{
    if (!_discoverCallbacks) {
        _discoverCallbacks = [NSMutableArray arrayWithCapacity:1];
    }
    return _discoverCallbacks;
}

- (NSMutableArray *)serviceBlocks{
    if (!_serviceCallbacks) {
        _serviceCallbacks = [NSMutableArray arrayWithCapacity:1];
    }
    return _serviceCallbacks;
}

- (NSMutableDictionary *)charactBlocks{
    if (!_charactCallbacks) {
        _charactCallbacks = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    return _charactCallbacks;
}

- (NSMutableArray *)rssiBlocks{
    if (!_rssiCallbacks) {
        _rssiCallbacks = [NSMutableArray arrayWithCapacity:1];
    }
    return _rssiCallbacks;
}

- (NSMutableDictionary *)readBlocks{
    if (!_readCallbacks) {
        _readCallbacks = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    return _readCallbacks;
}

- (NSMutableDictionary *)writBlocks{
    if (!_writeCallbacks) {
        _writeCallbacks = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    return _writeCallbacks;
}

- (NSMutableDictionary *)notifyStateBlocks{
    if (!_notifyStateCallbacks) {
        _notifyStateCallbacks = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    return _notifyStateCallbacks;
}

- (NSMutableDictionary *)notifyValueBlocks{
    if (!_notifyValueCallbacks) {
        _notifyValueCallbacks = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    return _notifyValueCallbacks;
}

- (NSMutableDictionary *)indicateStateBlocks{
    if (!_indicateStateCallbacks) {
        _indicateStateCallbacks = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    return _indicateStateCallbacks;
}

- (NSMutableDictionary *)indicateValueBlocks{
    if (!_indicateValueCallbacks) {
        _indicateValueCallbacks = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    return _indicateValueCallbacks;
}

- (void)cleanCallbacks {
    _discoverCallbacks = nil;
    _serviceCallbacks = nil;
    _charactCallbacks = nil;
    _rssiCallbacks  = nil;
    _readCallbacks  = nil;
    _writeCallbacks = nil;
    _notifyStateCallbacks = nil;
    _notifyValueCallbacks = nil;
    _indicateStateCallbacks = nil;
    _indicateValueCallbacks = nil;
}

- (void)addDiscoverCallback:(DiscoverCallback)block{
    NSMutableArray *callbacks = [self discoverBlocks];
    if (callbacks) {
        [callbacks addObject:[block copy]];
    }
}

- (void)handleDiscoverCallback:(BZPeripheral *)peripheral error:(NSError *)error{
    NSMutableArray *callbacks = [self discoverBlocks];
    if (callbacks && callbacks.count > 0) {
        for(DiscoverCallback callback in [callbacks copy]) {
            callback(peripheral, error);
        }
        [callbacks removeAllObjects];
    }
}

- (void)addDiscoverServiceCallback:(DiscoverServiceCallback)block{
    NSMutableArray *callbacks = [self serviceBlocks];
    if (callbacks) {
        [callbacks addObject:[block copy]];
    }
}

- (void)handleDiscoverServiceCallback:(BZPeripheral *)peripheral error:(NSError *)error{
    NSMutableArray *callbacks = [self serviceBlocks];
    if (callbacks && callbacks.count > 0) {
        for(DiscoverServiceCallback callback in [callbacks copy]) {
            callback(peripheral, error);
        }
        [callbacks removeAllObjects];
    }
}

- (void)addDiscoverCharactCallback:(CBUUID *)serviceUUID callback:(DiscoverCharactCallback)block{
    NSMutableDictionary *charactBlocks = [self charactBlocks];
    NSMutableArray *callbacks = charactBlocks[serviceUUID];
    if (!callbacks) {
        callbacks = [NSMutableArray arrayWithCapacity:1];
        charactBlocks[serviceUUID] = callbacks;
    }
    [callbacks addObject:[block copy]];
}

- (void)handleDiscoverCharactCallback:(CBService *)service error:(NSError *)error{
    NSMutableDictionary *charactBlocks = [self charactBlocks];
    NSMutableArray *callbacks = charactBlocks[service.UUID];
    if (callbacks) {
        for(DiscoverCharactCallback callback in [callbacks copy]) {
            callback(service, error);
        }
        [callbacks removeAllObjects];
    }
}

- (void)addRSSICallback:(RSSICallback)block{
    NSMutableArray *callbacks = [self rssiBlocks];
    if (callbacks) {
        [callbacks addObject:[block copy]];
    }
}

- (void)handleRSSICallback:(NSNumber *)value error:(NSError *)error{
    NSMutableArray *callbacks = [self rssiBlocks];
    if (callbacks && callbacks.count > 0) {
        for(RSSICallback callback in [callbacks copy]) {
            callback(value, error);
        }
        [callbacks removeAllObjects];
    }
}

#pragma mark - Peripheral function

- (BOOL)connect{
    if (!_blePeripheral) {
        NSLog(@"BZPeripheral connect fail, peripheral is null.");
        return NO;
    }
    if ([self isConnecting]) {
        NSLog(@"BZPeripheral connect fail, peripheral is connecting.");
        return NO;
    }
    if ([self isConnected]) {
        NSLog(@"BZPeripheral connect fail, peripheral is connected.");
        return NO;
    }
    [[BZCentralManager defaultManager] addPeripheral:self];
    [[BZCentralManager defaultManager] connectPeripheral:self];
    _state = BZPeripheralStateConnecting;
    [_connectStateDelegate didConnecting];
    return YES;
}

- (void)discoverServicesOnMainThread:(nullable NSArray<CBUUID *> *)serviceUUIDs{
    if (_blePeripheral) {
        [BZCentralManager runOnMainThread:^{
            [self->_blePeripheral discoverServices:serviceUUIDs];
        }];
    }
}

- (void)discoverCharacteristicsOnMainThread:(nullable NSArray<CBUUID *> *)charactUUIDs forService:(CBService *)service{
    if (_blePeripheral) {
        [BZCentralManager runOnMainThread:^{
            [self->_blePeripheral discoverCharacteristics:charactUUIDs forService:service];
        }];
    }
}

- (BOOL)discoverServices:(DiscoverCallback)callback{
    if ([self isConnected]) {
        //[discoverLock lock];
        if (_state != BZPeripheralStateDiscovering) {
            _state = BZPeripheralStateDiscovering;
            _isDiscoverServiceAll = YES;
            _discoverServiceCount = 0;
            [self cleanCallbacks];
            [self addDiscoverCallback:callback];
            [self discoverServicesOnMainThread:nil];
        } else {
            // All services are discovering
            [self addDiscoverCallback:callback];
        }
        //[discoverLock unlock];
        return YES;
    } else {
        NSError *error = [NTBLEError errorCode:ErrorCodeDisconnected
                                      userInfo:nil];
        if (callback) {
            callback(nil, error);
        }
        return NO;
    }
}

- (BOOL)discoverService:(NSArray *)serviceUUIDs callback:(DiscoverServiceCallback)callback{
    if ([self isConnected]) {
        //[discoverLock lock];
        if (_state != BZPeripheralStateDiscovering) {
            _state = BZPeripheralStateDiscovering;
            _isDiscoverServiceAll = NO;
            [self cleanCallbacks];
            [self addDiscoverServiceCallback:callback];
            [self discoverServicesOnMainThread:serviceUUIDs];
        } else {
            // All services are discovering
            [self addDiscoverServiceCallback:callback];
        }
        //[discoverLock unlock];
        return YES;
    } else {
        NSError *error = [NTBLEError errorCode:ErrorCodeDisconnected
                                      userInfo:nil];
        if (callback) {
            callback(nil, error);
        }
        return NO;
    }
}

- (BOOL)discoverCharact:(NSArray *)charactUUIDs forService:(CBService *)service callback:(DiscoverCharactCallback)callback{
    if ([self isConnected]) {
        [self addDiscoverCharactCallback:service.UUID callback:callback];
        [self discoverCharacteristicsOnMainThread:charactUUIDs forService:service];
        return YES;
    } else {
        NSError *error = [NTBLEError errorCode:ErrorCodeDisconnected
                                      userInfo:nil];
        if (callback) {
            callback(nil, error);
        }
        return NO;
    }
}

- (BOOL)isContainCharactWithUUID:(CBUUID *)serviceUUID charact:(CBUUID *)charactUUID{
    if (!_blePeripheral) {
        NSLog(@"BZPeripheral check contain charact fail, peripheral is null.");
        return NO;
    }
    NSArray *services = _blePeripheral.services;
    for (NSUInteger i = 0; i < services.count; i ++) {
        CBService *service = services[i];
        if ([serviceUUID isEqual:service.UUID]) {
            for (NSUInteger j = 0; j < service.characteristics.count; j++) {
                CBCharacteristic *charact = service.characteristics[j];
                if ([charactUUID isEqual:charact.UUID]) {
                    return YES;
                }
            }
        }
    }
    return NO;
}

- (BOOL)isContainCharactWithString:(NSString *)serviceUUIDString charact:(NSString *)charactUUIDString{
    CBUUID *serviceUUID = [self formUUID:serviceUUIDString];
    CBUUID *charactUUID = [self formUUID:charactUUIDString];
    return [self isContainCharactWithUUID:serviceUUID charact:charactUUID];
}

- (BOOL)disconnect {
    if (!_blePeripheral) {
        NSLog(@"BZPeripheral disconnect fail, peripheral is null.");
        return NO;
    }
    if (![self isConnected]) {
        NSLog(@"BZPeripheral disconnect fail, peripheral is disconnected.");
        return NO;
    }
    _state = BZPeripheralStateDisconnecting;
    [[BZCentralManager defaultManager] cancelPeripheral:self];
    return YES;
}

- (BOOL)readRSSI:(RSSICallback)callback{
    if ([self isConnected]) {
        [self addRSSICallback:callback];
        [_blePeripheral readRSSI];
        return YES;
    } else {
        NSError *error = [NTBLEError errorCode:ErrorCodeDisconnected
                                      userInfo:nil];
        if (callback) {
            callback(0, error);
        }
        return NO;
    }
}

- (BOOL)readWithCharact:(CBCharacteristic *)read callback:(ReadCallback)callback{
    BZPeripheralController *controller = [[BZPeripheralController alloc] initWithPeripheral:self];
    if (controller) {
        controller = [controller withCharact:read];
        if (controller) {
            return [controller readCharact:callback];
        }
    }
    return NO;
}

- (BOOL)readWithUUID:(CBUUID *)service charactUUID:(CBUUID *)read callback:(ReadCallback)callback{
    BZPeripheralController *controller = [[BZPeripheralController alloc] initWithPeripheral:self];
    if (controller) {
        controller = [controller withUUID:service charact:read];
        if (controller) {
            return [controller readCharact:callback];
        }
    }
    return NO;
}

- (BOOL)readWithUUIDString:(NSString *)service charactUUID:(NSString *)read callback:(ReadCallback)callback{
    CBUUID *serviceUUID = [self formUUID:service];
    CBUUID *charactUUID = [self formUUID:read];
    return [self readWithUUID:serviceUUID charactUUID:charactUUID callback:callback];
}

- (BOOL)writeWithCharact:(CBCharacteristic *)write  value:(NSData *)value callback:(ReadCallback)callback{
    BZPeripheralController *controller = [[BZPeripheralController alloc] initWithPeripheral:self];
    if (controller) {
        controller = [controller withCharact:write];
        if (controller) {
            return [controller writeCharact:value callback:callback];
        }
    }
    return NO;
}

- (BOOL)writeWithUUID:(CBUUID *)service charactUUID:(CBUUID *)write value:(NSData *)value callback:(WriteCallback)callback{
    BZPeripheralController *controller = [[BZPeripheralController alloc] initWithPeripheral:self];
    if (controller) {
        controller = [controller withUUID:service charact:write];
        if (controller) {
            return [controller writeCharact:value callback:callback];
        }
    }
    return NO;
}

- (BOOL)writeWithUUIDString:(NSString *)service charactUUID:(NSString *)write value:(NSData *)value callback:(WriteCallback)callback{
    CBUUID *serviceUUID = [self formUUID:service];
    CBUUID *charactUUID = [self formUUID:write];
    return [self writeWithUUID:serviceUUID charactUUID:charactUUID value:value callback:callback];
}

- (BOOL)setNotifyWithCharact:(CBCharacteristic *)notify enable:(BOOL)enable stateCallback:(NotifyCallback)stateCallback valueCallback:(NotifyCallback)valueCallback{
    BZPeripheralController *controller = [[BZPeripheralController alloc] initWithPeripheral:self];
    if (controller) {
        controller = [controller withCharact:notify];
        if (controller) {
            return [controller notifyCharact:enable stateCallback:stateCallback valueCallback:valueCallback];
        }
    }
    return NO;
}

- (BOOL)setNotifyWithUUID:(CBUUID *)service charactUUID:(CBUUID *)notify enable:(BOOL)enable stateCallback:(NotifyCallback)stateCallback valueCallback:(NotifyCallback)valueCallback{
    BZPeripheralController *controller = [[BZPeripheralController alloc] initWithPeripheral:self];
    if (controller) {
        controller = [controller withUUID:service charact:notify];
        if (controller) {
            return [controller notifyCharact:enable stateCallback:stateCallback valueCallback:valueCallback];
        }
    }
    return NO;
}

- (BOOL)setNotifyWithUUIDString:(NSString *)service charactUUID:(NSString *)notify enable:(BOOL)enable stateCallback:(NotifyCallback)stateCallback valueCallback:(NotifyCallback)valueCallback{
    CBUUID *serviceUUID = [self formUUID:service];
    CBUUID *charactUUID = [self formUUID:notify];
    return [self setNotifyWithUUID:serviceUUID charactUUID:charactUUID enable:enable stateCallback:stateCallback valueCallback:valueCallback];
}

- (BOOL)setIndicateWithCharact:(CBCharacteristic *)indicate enable:(BOOL)enable stateCallback:(IndicateCallback)stateCallback valueCallback:(IndicateCallback)valueCallback{
    BZPeripheralController *controller = [[BZPeripheralController alloc] initWithPeripheral:self];
    if (controller) {
        controller = [controller withCharact:indicate];
        if (controller) {
            return [controller indicateCharact:enable stateCallback:stateCallback valueCallback:valueCallback];
        }
    }
    return NO;
}

- (BOOL)setIndicateWithUUID:(CBUUID *)service charactUUID:(CBUUID *)indicate enable:(BOOL)enable stateCallback:(IndicateCallback)stateCallback valueCallback:(IndicateCallback)valueCallback{
    BZPeripheralController *controller = [[BZPeripheralController alloc] initWithPeripheral:self];
    if (controller) {
        controller = [controller withUUID:service charact:indicate];
        if (controller) {
            return [controller indicateCharact:enable stateCallback:stateCallback valueCallback:valueCallback];
        }
    }
    return NO;
}

- (BOOL)setIndicateWithUUIDString:(NSString *)service charactUUID:(NSString *)indicate enable:(BOOL)enable stateCallback:(IndicateCallback)stateCallback valueCallback:(IndicateCallback)valueCallback{
    CBUUID *serviceUUID = [self formUUID:service];
    CBUUID *charactUUID = [self formUUID:indicate];
    return [self setIndicateWithUUID:serviceUUID charactUUID:charactUUID enable:enable stateCallback:stateCallback valueCallback:valueCallback];
}

#pragma mark - Peripheral delgate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    [self updateBLEPeripheral:peripheral];
    if (_isDiscoverServiceAll) {
        _discoverServiceCount = peripheral.services.count;
        for (NSUInteger i = 0; i < peripheral.services.count; i ++) {
            CBService * service = peripheral.services[i];
            [peripheral discoverCharacteristics:nil forService:service];
        }
    } else {
        _state = BZPeripheralStateDiscovered;
        [self handleDiscoverServiceCallback:self error:error];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
    [self updateBLEPeripheral:peripheral];
    if (_isDiscoverServiceAll) {
        _discoverServiceCount--;
        if (_discoverServiceCount <= 0) {
            [self handleDiscoverCallback:self error:error];
            _state = BZPeripheralStateDiscovered;
        }
    } else {
        [self handleDiscoverCharactCallback:service error:error];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    for (CBDescriptor *desc in characteristic.descriptors) {
        NSLog(@"didDiscoverDescriptorForCharact:%@, desc:%@",characteristic.UUIDString, desc.UUIDString);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    NSString *state = characteristic.isNotifying ? @"On" : @"Off";
    NSLog(@"didUpdateNotifyOrIndicate:%@, state:%@", characteristic.UUIDString, state);
    BZPeripheralController *controller = [[BZPeripheralController alloc] initWithPeripheral:self];
    if (controller) {
        CBUUID *serviceUUID = characteristic.service.UUID;
        CBUUID *charactUUID = characteristic.UUID;
        controller = [controller withUUID:serviceUUID charact:charactUUID];
        if (controller) {
            [controller handleNotifyStateCallback:characteristic error:error];
            [controller handleIndicateStateCallback:characteristic error:error];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    NSLog(@"didUpdateValueForCharact:%@, error:%@", characteristic.UUIDString, error);
    BZPeripheralController *controller = [[BZPeripheralController alloc] initWithPeripheral:self];
    if (controller) {
        CBUUID *serviceUUID = characteristic.service.UUID;
        CBUUID *charactUUID = characteristic.UUID;
        controller = [controller withUUID:serviceUUID charact:charactUUID];
        if (controller) {
            [controller handleReadCallback:characteristic error:error];
            [controller handleNotifyValueCallback:characteristic error:error];
            [controller handleIndicateValueCallback:characteristic error:error];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error{
    NSLog(@"didUpdateValueForDesc:%@, error:%@", descriptor.UUIDString, error);
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    NSLog(@"didWriteValueForCharact:%@(%@), error:%@", characteristic.UUIDString, characteristic.value, error);
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error{
    NSLog(@"didWriteValueForDesc:%@, error:%@", descriptor.UUIDString, error);
}

- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral{
    NSLog(@"DidUpdateName:%@", peripheral.name);
}

- (void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(NSError *)error{
    [self handleRSSICallback:RSSI error:error];
}

@end
