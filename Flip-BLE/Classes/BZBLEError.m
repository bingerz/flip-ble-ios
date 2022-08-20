//
//  BZBLEError.m
//  Flip-BLE
//
//  Created by Hanson on 2022/8/18.
//

#import <Foundation/Foundation.h>
#import "BZBLEError.h"

static NSDictionary *errorDictionary = nil;

@implementation NTBLEError

+ (void)initialize {
    if (self == [NTBLEError class]) {
        errorDictionary = \
        @{
          @(ErrorCodeNone)          :   @"BZBLEError:None",
          @(ErrorCodeDisconnected)  :   @"BZBLEError:NTPeripheral is disconnected",
          @(ErrorCodeGattError)     :   @"BZBLEError:Gatt error",
          @(ErrorCodeScanFail)      :   @"BZBLEError:Scan Failure",
          @(ErrorCodeOther)         :   @"BZBLEError:Other",
          };
    }
}

+ (NSError *)errorCode:(BZBLEErrorCode)code userInfo:(NSDictionary *)dic {
    return [NSError errorWithDomain:errorDictionary[@(code)]
                               code:code
                           userInfo:dic];
}

+ (NSString *)transformCodeToStringInfo:(BZBLEErrorCode)code {
    return errorDictionary[@(code)];
}

@end
