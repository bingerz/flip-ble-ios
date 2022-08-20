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

@interface BZMultiplePeripheralController : NSObject

/**
 *  Singleton method
 *
 *  @return the shared instance with OS_LOG_DEFAULT.
 */
@property (class, readonly, strong) BZMultiplePeripheralController *sharedInstance;

- (void)addPeripheral:(BZPeripheral *)peripheral;

- (void)removePeripheral:(BZPeripheral *)peripheral;

- (void)removeAllPeripheral;

- (BZPeripheral *)getPeripheral:(NSString *)key;

- (void)disconnectAllPeripheral;

- (NSArray *)getPeripherals;

@end

#endif /* BZMultiplePeripheralController_h */
