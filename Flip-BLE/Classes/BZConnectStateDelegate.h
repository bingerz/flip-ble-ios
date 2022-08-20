//
//  BZConnectStateDelegate.h
//  Flip-BLE
//
//  Created by Hanson on 2022/8/18.
//

#ifndef BZConnectStateDelegate_h
#define BZConnectStateDelegate_h

#import "BZPeripheral.h"

@class BZPeripheral;

@protocol BZConnectStateDelegate <NSObject>

@optional
- (void)didConnecting;

- (void)didRetrieve:(BZPeripheral *)peripheral;
- (void)didRetrieveConnected:(BZPeripheral *)peripheral;
- (void)didConnected:(BZPeripheral *)peripheral;
- (void)didConnectError:(BZPeripheral *)peripheral error:(NSError *)error;
- (void)didDisconnected:(BZPeripheral *)peripheral error:(NSError *)error;
- (void)didRestored:(BZPeripheral *)peripheral;

@end

#endif /* BZConnectStateDelegate_h */
