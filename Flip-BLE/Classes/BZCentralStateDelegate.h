//
//  BZCentralStateDelegate.h
//  Flip-BLE
//
//  Created by Hanson on 2022/8/19.
//

#ifndef BZCentralStateDelegate_h
#define BZCentralStateDelegate_h

#import <CoreBluetooth/CoreBluetooth.h>

@class BZPeripheral;

NS_ASSUME_NONNULL_BEGIN

@protocol BZCentralStateDelegate <NSObject>

- (void)centralDidUpdateState:(CBManagerState)state;

@optional
- (void)centralDidRestorePeripheral:(BZPeripheral *)peripheral;

@end

NS_ASSUME_NONNULL_END

#endif /* BZCentralStateDelegate_h */
