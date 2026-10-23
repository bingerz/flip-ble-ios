//
//  BZCentralStateDelegate.h
//  Flip-BLE
//
//  Created by Hanson on 2022/8/19.
//

#ifndef BZCentralStateDelegate_h
#define BZCentralStateDelegate_h

#import <CoreBluetooth/CoreBluetooth.h>

NS_ASSUME_NONNULL_BEGIN

@protocol BZCentralStateDelegate <NSObject>

- (void)centralDidUpdateState:(CBManagerState)state;

@end

NS_ASSUME_NONNULL_END

#endif /* BZCentralStateDelegate_h */
