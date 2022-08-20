//
//  CBObject+BZAddition.m
//  Flip-BLE
//
//  Created by Hanson on 2022/8/18.
//

#import <Foundation/Foundation.h>
#import "CBObject+BZAddition.h"

@implementation CBPeripheral (UUIDString)

- (NSString *)UUIDString{
    if (self.identifier) {
        return [self.identifier UUIDString];
    }
    return nil;
}

@end

@implementation CBService (UUIDString)

- (NSString *)UUIDString{
    return self.UUID.UUIDString;
}

@end

@implementation CBCharacteristic (UUIDString)

- (NSString *)UUIDString{
    return self.UUID.UUIDString;
}

@end

@implementation CBDescriptor (UUIDString)

- (NSString *)UUIDString{
    return self.UUID.UUIDString;
}

@end

@implementation CBUUID (UUIDString)

- (NSString *)UUIDString{
    NSMutableString * s = [NSMutableString stringWithCapacity:self.data.length * 2 + 4];
    unsigned char * b = (unsigned char *)self.data.bytes;
    for (NSUInteger i = 0; i < self.data.length; i ++) {
        [s appendFormat:@"%02X", *(b + i)];
        switch (i) {
            case 3:
            case 5:
            case 7:
            case 9:
                [s appendString:@"-"];
                break;
            default:
                break;
        }
    }
    return [s copy];
}

@end
