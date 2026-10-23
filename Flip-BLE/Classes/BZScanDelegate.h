//
//  BZScanDelegate.h
//  Flip-BLE
//
//  Created by Hanson on 2022/8/18.
//

#ifndef BZScanDelegate_h
#define BZScanDelegate_h

#import <Foundation/Foundation.h>

@class BZPeripheral;

NS_ASSUME_NONNULL_BEGIN

@protocol BZScanDelegate <NSObject>

- (void)didScanning:(BZPeripheral *)peripheral advData:(NSDictionary<NSString *, id> *)advData;

@end

NS_ASSUME_NONNULL_END

#endif /* BZScanDelegate_h */
