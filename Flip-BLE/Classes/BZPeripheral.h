//
//  BZPeripheral.h
//  Flip-BLE
//
//  Created by Hanson on 2022/8/18.
//

#ifndef BZPeripheral_h
#define BZPeripheral_h

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "BZConnectStateDelegate.h"

typedef NS_ENUM(NSInteger, BZPeripheralState) {
    BZPeripheralStateDisconnected = 0,
    BZPeripheralStateConnecting,
    BZPeripheralStateConnected,
    BZPeripheralStateDiscovering,
    BZPeripheralStateDiscovered,
    BZPeripheralStateDisconnecting
};

typedef void (^DiscoverCallback)(BZPeripheral *peripheral, NSError *error);
typedef void (^DiscoverServiceCallback)(BZPeripheral *peripheral, NSError *error);
typedef void (^DiscoverCharactCallback)(CBService *service, NSError *error);
typedef void (^RSSICallback)(NSNumber *value, NSError *error);
typedef void (^ReadCallback)(CBCharacteristic *charact, NSError * error);
typedef void (^WriteCallback)(CBCharacteristic *charact, NSError * error);
typedef void (^NotifyCallback)(CBCharacteristic *charact, NSError * error);
typedef void (^IndicateCallback)(CBCharacteristic *charact, NSError * error);

@interface BZPeripheral : NSObject <CBPeripheralDelegate>

/*!
 *  @property delegate
 *
 *  @discussion The delegate object that will receive peripheral connection state events.
 */
@property (nonatomic, retain) id<BZConnectStateDelegate> connectStateDelegate;

@property (nonatomic, strong, readwrite) NSNumber *scannedRSSINumber;

- (id)initWithPeripheral:(CBPeripheral *)blePeripheral;

- (NSMutableArray *)discoverBlocks;
- (NSMutableArray *)serviceBlocks;
- (NSMutableDictionary *)charactBlocks;
- (NSMutableArray *)rssiBlocks;
- (NSMutableDictionary *)readBlocks;
- (NSMutableDictionary *)writBlocks;
- (NSMutableDictionary *)notifyStateBlocks;
- (NSMutableDictionary *)notifyValueBlocks;
- (NSMutableDictionary *)indicateStateBlocks;
- (NSMutableDictionary *)indicateValueBlocks;

- (void)cleanCallbacks;

- (CBPeripheral *)blePeripheral;
- (NSString *)bleState;
- (NSString *)name;
- (NSString *)UUIDString;
- (NSArray *)services;
- (BOOL)isConnecting;
- (BOOL)isConnected;
- (void)updateBLEPeripheral:(CBPeripheral *)peripheral;
- (void)updateStateWithBLEPeripheral:(CBPeripheral *)blePeripheral;

- (BOOL)connect;
- (BOOL)disconnect;

- (BOOL)discoverServices:(DiscoverCallback)callback;
- (BOOL)discoverService:(NSArray *)serviceUUIDs callback:(DiscoverServiceCallback)callback;
- (BOOL)discoverCharact:(NSArray *)charactUUIDs forService:(CBService *)service callback:(DiscoverCharactCallback)callback;

- (BOOL)isContainCharactWithUUID:(CBUUID *)serviceUUID charact:(CBUUID *)charactUUID;
- (BOOL)isContainCharactWithString:(NSString *)serviceUUIDString charact:(NSString *)charactUUIDString;

- (BOOL)readRSSI:(RSSICallback)block;

- (BOOL)readWithCharact:(CBCharacteristic *)read callback:(ReadCallback)callback;

- (BOOL)readWithUUID:(CBUUID *)service charactUUID:(CBUUID *)read callback:(ReadCallback)callback;

- (BOOL)readWithUUIDString:(NSString *)service charactUUID:(NSString *)read callback:(ReadCallback)callback;

- (BOOL)writeWithCharact:(CBCharacteristic *)write  value:(NSData *)value callback:(ReadCallback)callback;

- (BOOL)writeWithUUID:(CBUUID *)service charactUUID:(CBUUID *)write value:(NSData *)value callback:(WriteCallback)callback;

- (BOOL)writeWithUUIDString:(NSString *)service charactUUID:(NSString *)write value:(NSData *)value callback:(WriteCallback)callback;

- (BOOL)setNotifyWithCharact:(CBCharacteristic *)notify enable:(BOOL)enable stateCallback:(NotifyCallback)stateCallback valueCallback:(NotifyCallback)valueCallback;

- (BOOL)setNotifyWithUUID:(CBUUID *)service charactUUID:(CBUUID *)notify enable:(BOOL)enable stateCallback:(NotifyCallback)stateCallback valueCallback:(NotifyCallback)valueCallback;

- (BOOL)setNotifyWithUUIDString:(NSString *)service charactUUID:(NSString *)notify enable:(BOOL)enable stateCallback:(NotifyCallback)stateCallback valueCallback:(NotifyCallback)valueCallback;

- (BOOL)setIndicateWithCharact:(CBCharacteristic *)indicate enable:(BOOL)enable stateCallback:(IndicateCallback)stateCallback valueCallback:(IndicateCallback)valueCallback;

- (BOOL)setIndicateWithUUID:(CBUUID *)service charactUUID:(CBUUID *)notify enable:(BOOL)enable stateCallback:(IndicateCallback)stateCallback valueCallback:(IndicateCallback)valueCallback;

- (BOOL)setIndicateWithUUIDString:(NSString *)service charactUUID:(NSString *)notify enable:(BOOL)enable stateCallback:(IndicateCallback)stateCallback valueCallback:(IndicateCallback)valueCallback;

@end

#endif /* BZPeripheral_h */
