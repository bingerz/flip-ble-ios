//
//  BZCentralManager.m
//  Flip-BLE
//
//  Created by Hanson on 2022/8/18.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "BZBLEUtils.h"
#import "CBObject+BZAddition.h"
#import "BZCentralManager.h"
#import "BZMultiplePeripheralController.h"

@interface BZCentralManager () <CBCentralManagerDelegate> {
    BOOL _centralPoweredOn;
    CBCentralManager *_centralManager;
    BZMultiplePeripheralController *_multiplePeripheralController;
}
@property (nonatomic, strong, readwrite) NSDictionary *services;
@end

@implementation BZCentralManager

+ (BZCentralManager *)defaultManager {
    static BZCentralManager *defaultManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultManager = [[BZCentralManager alloc] init];
    });
    return defaultManager;
}

+ (void)runOnMainThread:(void (^)(void))block{
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            block();
        });
    }
}

- (id)init {
    self = [super init];
    if (self) {
        // init property
    }
    return self;
}

- (CBCentralManager *)centralManager {
    return _centralManager;
}

- (void)startCentralWithOptions:(NSDictionary<NSString *, id> *)options {
    if (!_centralManager) {
        dispatch_queue_global_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                        queue:queue
                                                      options:options];
        _multiplePeripheralController = [BZMultiplePeripheralController sharedInstance];
        NSLog(@"BZCentralManager startCentral finish");
    }
}

- (void)startCentralWithRestoreIdKey:(NSString *)key showPowerAlert:(BOOL)showAlert {
    NSMutableDictionary *options = [NSMutableDictionary dictionaryWithCapacity:2];
    if (key) {
        [options setObject:key forKey:CBCentralManagerOptionRestoreIdentifierKey];
    }
    [options setObject:@(showAlert) forKey:CBCentralManagerOptionShowPowerAlertKey];
    [self startCentralWithOptions:options];
}

- (void)restartCentralWithRestoreIdKey:(NSString *)key showPowerAlert:(BOOL)showAlert {
    if (_centralManager) {
        __weak __typeof(self)weakSelf = self;
        dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            __strong __typeof(self) strongSelf = weakSelf;
            [strongSelf stopScan];
            if (strongSelf->_multiplePeripheralController) {
                [strongSelf->_multiplePeripheralController disconnectAllPeripheral];
                [strongSelf->_multiplePeripheralController removeAllPeripheral];
                strongSelf->_multiplePeripheralController  = nil;
            }
            strongSelf->_centralManager = nil;
            [strongSelf startCentralWithRestoreIdKey:key showPowerAlert:showAlert];
            NSLog(@"BZCentralManager restartCentral finish");
        });
    } else {
        [self startCentralWithRestoreIdKey:key showPowerAlert:showAlert];
        NSLog(@"BZCentralManager restartCentral finish");
    }
}

- (void)destroyCentral {
    if (_centralManager) {
        __weak __typeof(self)weakSelf = self;
        dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            __strong __typeof(self) strongSelf = weakSelf;
            [strongSelf stopScan];
            if (strongSelf->_multiplePeripheralController) {
                [strongSelf->_multiplePeripheralController disconnectAllPeripheral];
                [strongSelf->_multiplePeripheralController removeAllPeripheral];
                strongSelf->_multiplePeripheralController  = nil;
            }
            strongSelf->_centralManager = nil;
            NSLog(@"BZCentralManager destroyCentral finish");
        });
    }
    if (_multiplePeripheralController) {
        [_multiplePeripheralController disconnectAllPeripheral];
        [_multiplePeripheralController removeAllPeripheral];
        _multiplePeripheralController  = nil;
    }
}

- (BOOL)isStateUnknown{
    return _centralManager.state == CBManagerStateUnknown;
}

- (BOOL)isStateResetting{
    return _centralManager.state == CBManagerStateResetting;
}

- (BOOL)isStateUnsupported{
    return _centralManager.state == CBManagerStateUnsupported;
}

- (BOOL)isStateUnauthorized{
    return _centralManager.state == CBManagerStateUnauthorized;
}

- (BOOL)isStatePoweredOff{
    return _centralManager.state == CBManagerStatePoweredOff;
}

- (BOOL)isStatePoweredOn{
    return _centralManager.state == CBManagerStatePoweredOn;
}

#pragma mark - Scan peripheral

- (void)scanWithServices:(NSArray<CBUUID *> *)serviceUUIDs options:(NSDictionary<NSString *, id> *)options {
    NSLog(@"scanWithServices %@ options %@", serviceUUIDs ? serviceUUIDs : @"nil", options ? options : @"nil");
    [BZCentralManager runOnMainThread:^{
        [self->_centralManager scanForPeripheralsWithServices:serviceUUIDs options:options];
        self.scanning = YES;
    }];
}

- (void)startScanWithServices:(NSArray<CBUUID *> *)serviceUUIDs allowDup:(BOOL)allowDup {
    NSMutableDictionary *options = [NSMutableDictionary dictionaryWithCapacity:1];
    [options BZ_setObject:@(allowDup) forKey:CBCentralManagerScanOptionAllowDuplicatesKey];
    [self scanWithServices:serviceUUIDs options:options];
}

- (void)stopScan {
    [BZCentralManager runOnMainThread:^{
        if (self.scanning) {
            [self->_centralManager stopScan];
            self.scanning = NO;
        }
    }];
}

#pragma mark - Retrieve peripheral

- (NSArray<BZPeripheral *> *)retrievePeripherals:(NSArray<NSString *> *)identifiers {
    if (!identifiers || ![identifiers count]) {
        NSLog(@"retrievePeripherals: identifiers is null");
        return nil;
    }
    NSLog(@"retrievePeripherals: %lu", (unsigned long)identifiers.count);
    NSMutableArray *newIDs = [NSMutableArray arrayWithArray:identifiers];
    NSInteger index = 0;
    for (id identifier in identifiers) {
        if ([identifier isKindOfClass:[NSString class]]) {
            [newIDs replaceObjectAtIndex:index withObject:[[NSUUID alloc] initWithUUIDString:identifier]];
        }
        index++;
    }
    NSArray *blePeripherals = [_centralManager retrievePeripheralsWithIdentifiers:newIDs];
    NSUInteger capacity = blePeripherals ? blePeripherals.count : 0;
    NSMutableArray *peripherals = [NSMutableArray arrayWithCapacity:capacity];
    for(CBPeripheral *p in blePeripherals) {
        [peripherals addObject:[[BZPeripheral alloc] initWithPeripheral:p]];
    }
    return peripherals;
}

- (NSArray<BZPeripheral *> *)retrieveConnectedPeripherals:(NSArray<CBUUID *> *)serviceUUIDs {
    if (!serviceUUIDs || ![serviceUUIDs count]) {
        NSLog(@"retrieveConnectedPeripherals: serviceUUIDs is null");
        return nil;
    }
    NSLog(@"retrieveConnectedPeripherals: %lu", (unsigned long)serviceUUIDs.count);
    NSArray *blePeripherals = [_centralManager retrieveConnectedPeripheralsWithServices:serviceUUIDs];
    NSUInteger capacity = blePeripherals ? blePeripherals.count : 0;
    NSMutableArray *peripherals = [NSMutableArray arrayWithCapacity:capacity];
    for(CBPeripheral *p in blePeripherals) {
        [peripherals addObject:[[BZPeripheral alloc] initWithPeripheral:p]];
    }
    return peripherals;
}

#pragma mark - Connect peripheral

- (void)connectPeripheral:(BZPeripheral *)peripheral {
    if (peripheral && peripheral.blePeripheral) {
        NSLog(@"ConnectPeripheral, peripheral %@", peripheral.UUIDString);
        [BZCentralManager runOnMainThread:^{
            [self->_centralManager connectPeripheral:peripheral.blePeripheral options:nil];
        }];
    } else {
        NSLog(@"connectPeripheral fail, peripheral is null.");
    }
}

- (void)cancelPeripheral:(BZPeripheral *)peripheral {
    if (peripheral && peripheral.blePeripheral) {
        NSLog(@"CancelPeripheral, peripheral %@", peripheral.UUIDString);
        [BZCentralManager runOnMainThread:^{
            [self->_centralManager cancelPeripheralConnection:peripheral.blePeripheral];
        }];
    } else {
        NSLog(@"cancelPeripheral fail, peripheral is null.");
    }
}

#pragma mark - Multiple peripheral manager

- (void)addPeripheral:(BZPeripheral *)peripheral {
    if (_multiplePeripheralController) {
        [_multiplePeripheralController addPeripheral:peripheral];
    } else {
        NSLog(@"addPeripheral fail, multiplePeripheralController is null");
    }
}

- (void)removePeripheral:(BZPeripheral *)peripheral {
    if (_multiplePeripheralController) {
        [_multiplePeripheralController removePeripheral:peripheral];
    } else {
        NSLog(@"removePeripheral fail, multiplePeripheralController is null");
    }
}

- (BZPeripheral *)getPeripheral:(NSString *)uuidString {
    if (_multiplePeripheralController) {
        return [_multiplePeripheralController getPeripheral:uuidString];
    }
    NSLog(@"getPeripheral fail, multiplePeripheralController is null");
    return nil;
}

#pragma mark - Delegates

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    switch (central.state) {
        case CBManagerStatePoweredOff:
            // When initialized, the state triggers PoweredOff first and then PoweredOn,
            // using variables to avoid the first PoweredOff.
            if (_centralPoweredOn) {
                [self.centralStateDelegate centralDidUpdateState:central.state];
            }
            _centralPoweredOn = NO;
            break;
        case CBManagerStatePoweredOn:
            [self.centralStateDelegate centralDidUpdateState:central.state];
            _centralPoweredOn = YES;
            break;
        default:
            [self.centralStateDelegate centralDidUpdateState:central.state];
            break;
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advData RSSI:(NSNumber *)RSSI {
    [BZCentralManager runOnMainThread:^{
        BZPeripheral *newPeripheral = [[BZPeripheral alloc] initWithPeripheral:peripheral];
        newPeripheral.scannedRSSINumber = RSSI;
        [self->_scanDelegate didScanning:newPeripheral advData:advData];
    }];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"didConnectPeripheral:%@(%@)", peripheral.name, peripheral.UUIDString);
    [BZCentralManager runOnMainThread:^{
        BZPeripheral *localPeripheral = [self getPeripheral:peripheral.UUIDString];
        if (localPeripheral) {
            [localPeripheral updateBLEPeripheral:peripheral];
            [localPeripheral updateStateWithBLEPeripheral:peripheral];
            [localPeripheral.connectStateDelegate didConnected:localPeripheral];
        } else {
            NSLog(@"didConnectPeripheral local peripheral is null.");
        }
    }];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"didFailToConnectPeripheral:%@(%@)", peripheral.name, peripheral.UUIDString);
    [BZCentralManager runOnMainThread:^{
        BZPeripheral *localPeripheral = [self getPeripheral:peripheral.UUIDString];
        if (localPeripheral) {
            [self removePeripheral:localPeripheral];
            [localPeripheral updateBLEPeripheral:peripheral];
            [localPeripheral updateStateWithBLEPeripheral:peripheral];
            [localPeripheral.connectStateDelegate didConnectError:localPeripheral error:error];
            [localPeripheral cleanCallbacks];
        } else {
            NSLog(@"didFailToConnectPeripheral local peripheral is null.");
        }
    }];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"didDisconnectPeripheral:%@(%@) with error:%@", peripheral.name, peripheral.UUIDString, error);
    [BZCentralManager runOnMainThread:^{
        BZPeripheral *localPeripheral = [self getPeripheral:peripheral.UUIDString];
        if (localPeripheral) {
            [self removePeripheral:localPeripheral];
            [localPeripheral updateBLEPeripheral:peripheral];
            [localPeripheral updateStateWithBLEPeripheral:peripheral];
            [localPeripheral.connectStateDelegate didDisconnected:localPeripheral error:error];
            [localPeripheral cleanCallbacks];
        } else {
            NSLog(@"didDisconnectPeripheral local peripheral is null.");
        }
    }];
}

- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary *)dict {
    NSLog(@"willRestoreState:%@", dict ? dict.description : @"nil");
    [BZCentralManager runOnMainThread:^{
        NSArray *peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey];
        for (CBPeripheral *peripheral in peripherals) {
            BZPeripheral *localPeripheral = [self getPeripheral:peripheral.UUIDString];
            if (localPeripheral) {
                [localPeripheral updateBLEPeripheral:peripheral];
                [localPeripheral updateStateWithBLEPeripheral:peripheral];
                [localPeripheral.connectStateDelegate didRestored:localPeripheral];
            }
        }
    }];
}

@end
