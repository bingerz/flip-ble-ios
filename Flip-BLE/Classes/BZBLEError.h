//
//  BZBLEError.h
//  Flip-BLE
//
//  Created by Hanson on 2022/8/18.
//

#ifndef BZBLEError_h
#define BZBLEError_h

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, BZBLEErrorCode) {
    ErrorCodeNone = 0,
    ErrorCodeDisconnected = -10000,
    ErrorCodeGattError,
    ErrorCodeScanFail,
    ErrorCodeOther
};

@interface NTBLEError : NSObject

+ (NSError *)errorCode:(BZBLEErrorCode)code userInfo:(NSDictionary *)dic;
+ (NSString *)transformCodeToStringInfo:(BZBLEErrorCode)code;

@end

#endif /* BZBLEError_h */
