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

@interface BZCentralManager : NSObject <CBCentralManagerDelegate>

@property (nonatomic, assign, readwrite, getter = isScanning) BOOL scanning;

@property (nonatomic, readonly) CBCentralManager *centralManager;

/*!
 *  @property delegate
 *
 *  @discussion The delegate object that will receive peripheral connection state events.
 */
@property (nonatomic, retain) id<BZScanDelegate> scanDelegate;

/*!
 * @property delegate
 *
 * @discussion The delegate object that will receive centralManager state events.
 */
@property (nonatomic, retain) id<BZCentralStateDelegate> centralStateDelegate;

+ (BZCentralManager *)defaultManager;
+ (void)runOnMainThread:(void (^)(void))block;

- (void)startCentralWithRestoreIdKey:(NSString *)key showPowerAlert:(BOOL)showAlert;
- (void)restartCentralWithRestoreIdKey:(NSString *)key showPowerAlert:(BOOL)showAlert;
- (void)destroyCentral;

- (BOOL)isStateUnknown;
- (BOOL)isStateResetting;
- (BOOL)isStateUnsupported;
- (BOOL)isStateUnauthorized;
- (BOOL)isStatePoweredOff;
- (BOOL)isStatePoweredOn;

// Scan peripheral
- (void)startScanWithServices:(NSArray<CBUUID *> *)serviceUUIDs allowDup:(BOOL)allowDup;
- (void)stopScan;

// Retrieve peripheral
- (NSArray<BZPeripheral *> *)retrievePeripherals:(NSArray<NSString *> *)identifiers;
- (NSArray<BZPeripheral *> *)retrieveConnectedPeripherals:(NSArray<CBUUID *> *)serviceUUIDs;

// Connect peripheral
- (void)connectPeripheral:(BZPeripheral *)peripheral;
- (void)cancelPeripheral:(BZPeripheral *)peripheral;

// Multiple peripheral manager
- (void)addPeripheral:(BZPeripheral *)peripheral;
- (void)removePeripheral:(BZPeripheral *)peripheral;
- (BZPeripheral *)getPeripheral:(NSString *)uuidString;

@end

#endif /* BZCentralManager_h */
