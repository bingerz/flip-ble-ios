//
//  BZMultiplePeripheralController.h
//  Flip-BLE
//
//  Created by Hanson on 2022/8/18.
//

#ifndef BZMultiplePeripheralController_h
#define BZMultiplePeripheralController_h

#import <Foundation/Foundation.h>
#import "BZPeripheral.h"

NS_ASSUME_NONNULL_BEGIN

@interface BZMultiplePeripheralController : NSObject

@property (class, readonly) BZMultiplePeripheralController *sharedInstance;

- (void)addPeripheral:(BZPeripheral *)peripheral;

- (void)removePeripheral:(BZPeripheral *)peripheral;

- (void)removeAllPeripheral;

- (nullable BZPeripheral *)getPeripheral:(NSString *)key;

- (void)disconnectAllPeripheral;

- (NSArray<BZPeripheral *> *)getPeripherals;

@end

NS_ASSUME_NONNULL_END

#endif /* BZMultiplePeripheralController_h */
