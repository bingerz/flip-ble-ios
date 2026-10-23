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

@class BZPeripheral;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, BZPeripheralState) {
    BZPeripheralStateDisconnected = 0,
    BZPeripheralStateConnecting,
    BZPeripheralStateConnected,
    BZPeripheralStateDiscovering,
    BZPeripheralStateDiscovered,
    BZPeripheralStateDisconnecting
};

typedef void (^DiscoverCallback)(BZPeripheral * _Nullable peripheral, NSError * _Nullable error) NS_SWIFT_NAME(BZPeripheral.DiscoverHandler);
typedef void (^DiscoverServiceCallback)(BZPeripheral * _Nullable peripheral, NSError * _Nullable error) NS_SWIFT_NAME(BZPeripheral.DiscoverServiceHandler);
typedef void (^DiscoverCharactCallback)(CBService * _Nullable service, NSError * _Nullable error) NS_SWIFT_NAME(BZPeripheral.DiscoverCharacteristicHandler);
typedef void (^RSSICallback)(NSNumber * _Nullable value, NSError * _Nullable error) NS_SWIFT_NAME(BZPeripheral.RSSIHandler);
typedef void (^ReadCallback)(CBCharacteristic * _Nullable characteristic, NSError * _Nullable error) NS_SWIFT_NAME(BZPeripheral.ReadHandler);
typedef void (^WriteCallback)(CBCharacteristic * _Nullable characteristic, NSError * _Nullable error) NS_SWIFT_NAME(BZPeripheral.WriteHandler);
typedef void (^NotifyCallback)(CBCharacteristic * _Nullable characteristic, NSError * _Nullable error) NS_SWIFT_NAME(BZPeripheral.NotifyHandler);
typedef void (^IndicateCallback)(CBCharacteristic * _Nullable characteristic, NSError * _Nullable error) NS_SWIFT_NAME(BZPeripheral.IndicateHandler);

@interface BZPeripheral : NSObject <CBPeripheralDelegate>

@property (nonatomic, retain, nullable) id<BZConnectStateDelegate> connectStateDelegate;

@property (nonatomic, strong, nullable) NSNumber *scannedRSSINumber;

- (instancetype)initWithPeripheral:(CBPeripheral *)blePeripheral;

@property (nonatomic, readonly, nullable) CBPeripheral *blePeripheral;
@property (nonatomic, readonly) NSString *bleState;
@property (nonatomic, readonly, nullable) NSString *name;
@property (nonatomic, readonly, nullable) NSString *UUIDString;
@property (nonatomic, readonly, nullable) NSArray<CBService *> *services;
@property (nonatomic, readonly, getter=isConnecting) BOOL connecting;
@property (nonatomic, readonly, getter=isConnected) BOOL connected;
@property (nonatomic, readonly) BZPeripheralState state;

- (void)updateBLEPeripheral:(CBPeripheral *)peripheral;
- (void)updateStateWithBLEPeripheral:(CBPeripheral *)blePeripheral;

- (BOOL)connect;
- (BOOL)disconnect;

- (BOOL)discoverServices:(DiscoverCallback)callback;
- (BOOL)discoverService:(nullable NSArray<CBUUID *> *)serviceUUIDs callback:(DiscoverServiceCallback)callback;
- (BOOL)discoverCharact:(nullable NSArray<CBUUID *> *)charactUUIDs forService:(CBService *)service callback:(DiscoverCharactCallback)callback;

- (BOOL)isContainCharactWithUUID:(CBUUID *)serviceUUID charact:(CBUUID *)charactUUID;
- (BOOL)isContainCharactWithString:(NSString *)serviceUUIDString charact:(NSString *)charactUUIDString;

- (BOOL)readRSSI:(RSSICallback)block;

- (BOOL)readWithCharact:(CBCharacteristic *)read callback:(ReadCallback)callback;

- (BOOL)readWithUUID:(CBUUID *)service charactUUID:(CBUUID *)read callback:(ReadCallback)callback;

- (BOOL)readWithUUIDString:(NSString *)service charactUUID:(NSString *)read callback:(ReadCallback)callback;

- (BOOL)writeWithCharact:(CBCharacteristic *)write value:(NSData *)value callback:(WriteCallback)callback;

- (BOOL)writeWithUUID:(CBUUID *)service charactUUID:(CBUUID *)write value:(NSData *)value callback:(WriteCallback)callback;

- (BOOL)writeWithUUIDString:(NSString *)service charactUUID:(NSString *)write value:(NSData *)value callback:(WriteCallback)callback;

- (BOOL)setNotifyWithCharact:(CBCharacteristic *)notify enable:(BOOL)enable stateCallback:(NotifyCallback)stateCallback valueCallback:(NotifyCallback)valueCallback;

- (BOOL)setNotifyWithUUID:(CBUUID *)service charactUUID:(CBUUID *)notify enable:(BOOL)enable stateCallback:(NotifyCallback)stateCallback valueCallback:(NotifyCallback)valueCallback;

- (BOOL)setNotifyWithUUIDString:(NSString *)service charactUUID:(NSString *)notify enable:(BOOL)enable stateCallback:(NotifyCallback)stateCallback valueCallback:(NotifyCallback)valueCallback;

- (BOOL)setIndicateWithCharact:(CBCharacteristic *)indicate enable:(BOOL)enable stateCallback:(IndicateCallback)stateCallback valueCallback:(IndicateCallback)valueCallback;

- (BOOL)setIndicateWithUUID:(CBUUID *)service charactUUID:(CBUUID *)notify enable:(BOOL)enable stateCallback:(IndicateCallback)stateCallback valueCallback:(IndicateCallback)valueCallback;

- (BOOL)setIndicateWithUUIDString:(NSString *)service charactUUID:(NSString *)notify enable:(BOOL)enable stateCallback:(IndicateCallback)stateCallback valueCallback:(IndicateCallback)valueCallback;

@end

NS_ASSUME_NONNULL_END

#endif /* BZPeripheral_h */
