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
#import "BZPeripheralController.h"
#import "BZBLECallback.h"

typedef NS_ENUM(NSInteger, BZPeripheralState) {
    BZPeripheralStateDisconnected = 0,
    BZPeripheralStateConnecting,
    BZPeripheralStateConnected,
    BZPeripheralStateDiscovering,
    BZPeripheralStateDiscovered,
    BZPeripheralStateDisconnecting
};

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
- (NSMutableDictionary *)notifyBlocks;
- (NSMutableDictionary *)readBlocks;
- (NSMutableDictionary *)writBlocks;

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

- (BOOL)setNotifyWithCharact:(CBCharacteristic *)notify enable:(BOOL)enable callback:(NotifyCallback)callback;

- (BOOL)setNotifyWithUUID:(CBUUID *)service charactUUID:(CBUUID *)notify enable:(BOOL)enable callback:(NotifyCallback)callback;

- (BOOL)setNotifyWithUUIDString:(NSString *)service charactUUID:(NSString *)notify enable:(BOOL)enable  callback:(NotifyCallback)callback;

- (BOOL)readWithCharact:(CBCharacteristic *)read callback:(ReadCallback)callback;

- (BOOL)readWithUUID:(CBUUID *)service charactUUID:(CBUUID *)read callback:(ReadCallback)callback;

- (BOOL)readWithUUIDString:(NSString *)service charactUUID:(NSString *)read callback:(ReadCallback)callback;

- (BOOL)writeWithCharact:(CBCharacteristic *)write  value:(NSData *)value callback:(ReadCallback)callback;

- (BOOL)writeWithUUID:(CBUUID *)service charactUUID:(CBUUID *)write value:(NSData *)value callback:(WriteCallback)callback;

- (BOOL)writeWithUUIDString:(NSString *)service charactUUID:(NSString *)write value:(NSData *)value callback:(WriteCallback)callback;

@end

#endif /* BZPeripheral_h */
