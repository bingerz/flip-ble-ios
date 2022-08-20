//
//  BZBLEUtils.m
//  Flip-BLE
//
//  Created by Hanson on 2022/8/18.
//

#import "BZBLEUtils.h"

@implementation BZBLEUtils

@end


@implementation NSDictionary (BZ)

- (BOOL)BZ_isValidForKey:(NSString *)key{
    return [self objectForKey:key] && [NSNull null] != (NSNull *)[self objectForKey:key];
}

@end

@implementation NSMutableDictionary (BZ)

- (BOOL)BZ_isValidForKey:(NSString *)key{
    return [self objectForKey:key] && [NSNull null] != (NSNull *)[self objectForKey:key];
}

- (void)BZ_setObject:(id)anObject forKey:(id)aKey{
    if (anObject && aKey) {
        [self setObject:anObject forKey:aKey];
    }
}

@end
