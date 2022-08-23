//
//  BZScanDelegate.h
//  Flip-BLE
//
//  Created by Hanson on 2022/8/18.
//

#ifndef BZScanDelegate_h
#define BZScanDelegate_h

#import "BZPeripheral.h"

@class BZPeripheral;

@protocol BZScanDelegate <NSObject>

- (void)didScanning:(BZPeripheral *)peripheral advData:(NSDictionary *)advData;

@end

#endif /* BZScanDelegate_h */
