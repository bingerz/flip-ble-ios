//
//  BZCentralStateDelegate.h
//  Flip-BLE
//
//  Created by Hanson on 2022/8/19.
//

#ifndef BZCentralStateDelegate_h
#define BZCentralStateDelegate_h

#import <CoreBluetooth/CoreBluetooth.h>

@protocol BZCentralStateDelegate <NSObject>

- (void)centralDidUpdateState:(CBManagerState)state;

@end

#endif /* BZCentralStateDelegate_h */
