//
//  BZCentralManager.h
//  Pods
//
//  Created by Hanson on 2022/8/18.
//

#ifndef BZCentralManager_h
#define BZCentralManager_h

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

#import "BZScanDelegate.h"
#import "BZCentralStateDelegate.h"
#import "BZPeripheral.h"

NS_ASSUME_NONNULL_BEGIN

@interface BZCentralManager : NSObject <CBCentralManagerDelegate>

@property (nonatomic, assign, readwrite, getter = isScanning) BOOL scanning;

@property (nonatomic, readonly, nullable) CBCentralManager *centralManager;

@property (nonatomic, retain, nullable) id<BZScanDelegate> scanDelegate;

@property (nonatomic, retain, nullable) id<BZCentralStateDelegate> centralStateDelegate;

+ (BZCentralManager *)defaultManager;
+ (void)runOnMainThread:(void (^)(void))block;

- (void)startCentralWithRestoreIdKey:(nullable NSString *)key showPowerAlert:(BOOL)showAlert;
- (void)restartCentralWithRestoreIdKey:(nullable NSString *)key showPowerAlert:(BOOL)showAlert;
- (void)destroyCentral;

- (BOOL)isStateUnknown;
- (BOOL)isStateResetting;
- (BOOL)isStateUnsupported;
- (BOOL)isStateUnauthorized;
- (BOOL)isStatePoweredOff;
- (BOOL)isStatePoweredOn;

- (void)startScanWithServices:(nullable NSArray<CBUUID *> *)serviceUUIDs allowDup:(BOOL)allowDup;
- (void)stopScan;

- (nullable NSArray<BZPeripheral *> *)retrievePeripherals:(NSArray<NSString *> *)identifiers;
- (nullable NSArray<BZPeripheral *> *)retrieveConnectedPeripherals:(NSArray<CBUUID *> *)serviceUUIDs;

- (void)connectPeripheral:(BZPeripheral *)peripheral;
- (void)cancelPeripheral:(BZPeripheral *)peripheral;

- (void)addPeripheral:(BZPeripheral *)peripheral;
- (void)removePeripheral:(BZPeripheral *)peripheral;
- (nullable BZPeripheral *)getPeripheral:(NSString *)uuidString;

@end

NS_ASSUME_NONNULL_END

#endif /* BZCentralManager_h */
