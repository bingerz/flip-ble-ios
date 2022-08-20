//
//  BZBLEUtils.h
//  Flip-BLE
//
//  Created by Hanson on 2022/8/18.
//

#ifndef BZBLEUtils_h
#define BZBLEUtils_h

#import <Foundation/Foundation.h>

@interface BZBLEUtils : NSObject

@end

@interface NSDictionary (BZ)

- (BOOL)BZ_isValidForKey:(NSString *)key;

@end

@interface NSMutableDictionary (BZ)

- (BOOL)BZ_isValidForKey:(NSString *)key;
- (void)BZ_setObject:(id)anObject forKey:(id)aKey;

@end

#endif /* BZBLEUtils_h */
