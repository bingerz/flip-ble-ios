//
//  BZConnectStateDelegate.h
//  Flip-BLE
//
//  Created by Hanson on 2022/8/18.
//

#ifndef BZConnectStateDelegate_h
#define BZConnectStateDelegate_h

#import <Foundation/Foundation.h>

@class BZPeripheral;

NS_ASSUME_NONNULL_BEGIN

@protocol BZConnectStateDelegate <NSObject>

@optional
- (void)didConnecting;
- (void)didConnectingPeripheral:(BZPeripheral *)peripheral;

- (void)didRetrieve:(BZPeripheral *)peripheral;
- (void)didRetrieveConnected:(BZPeripheral *)peripheral;
- (void)didConnected:(BZPeripheral *)peripheral;
- (void)didConnectError:(BZPeripheral *)peripheral error:(nullable NSError *)error;
- (void)didDisconnected:(BZPeripheral *)peripheral error:(nullable NSError *)error;
- (void)didRestored:(BZPeripheral *)peripheral;

@end

NS_ASSUME_NONNULL_END

#endif /* BZConnectStateDelegate_h */
