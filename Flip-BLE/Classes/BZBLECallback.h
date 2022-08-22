//
//  BZBLECallback.h
//  Flip-BLE
//
//  Created by Hanson on 2022/8/18.
//

#ifndef BZBLECallback_h
#define BZBLECallback_h

#import <Foundation/Foundation.h>
#import "BZPeripheral.h"

@class BZPeripheral;

typedef void (^DiscoverCallback)(BZPeripheral *peripheral, NSError *error);
typedef void (^DiscoverServiceCallback)(BZPeripheral *peripheral, NSError *error);
typedef void (^DiscoverCharactCallback)(CBService *service, NSError *error);
typedef void (^RSSICallback)(NSNumber *value, NSError *error);
typedef void (^NotifyCallback)(CBCharacteristic *charact, NSError * error);
typedef void (^ReadCallback)(CBCharacteristic *charact, NSError * error);
typedef void (^WriteCallback)(CBCharacteristic *charact, NSError * error);

#endif /* BZBLECallback_h */
