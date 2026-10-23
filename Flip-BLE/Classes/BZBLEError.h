//
//  BZBLEError.h
//  Flip-BLE
//
//  Created by Hanson on 2022/8/18.
//

#ifndef BZBLEError_h
#define BZBLEError_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, BZBLEErrorCode) {
    BZBLEErrorCodeNone = 0,
    BZBLEErrorCodeDisconnected = -10000,
    BZBLEErrorCodeGattError,
    BZBLEErrorCodeScanFail,
    BZBLEErrorCodeOther
};

#define ErrorCodeNone BZBLEErrorCodeNone
#define ErrorCodeDisconnected BZBLEErrorCodeDisconnected
#define ErrorCodeGattError BZBLEErrorCodeGattError
#define ErrorCodeScanFail BZBLEErrorCodeScanFail
#define ErrorCodeOther BZBLEErrorCodeOther

NS_SWIFT_NAME(LegacyBLEError)
@interface NTBLEError : NSObject

+ (NSError *)errorCode:(BZBLEErrorCode)code userInfo:(nullable NSDictionary *)dic;
+ (nullable NSString *)transformCodeToStringInfo:(BZBLEErrorCode)code;

@end

NS_ASSUME_NONNULL_END

#endif /* BZBLEError_h */
