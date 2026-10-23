//
//  BZBLEUtils.h
//  Flip-BLE
//
//  Created by Hanson on 2022/8/18.
//

#ifndef BZBLEUtils_h
#define BZBLEUtils_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BZBLEUtils : NSObject

@end

@interface NSDictionary (BZ)

- (BOOL)BZ_isValidForKey:(NSString *)key;

@end

@interface NSMutableDictionary (BZ)

- (BOOL)BZ_isValidForKey:(NSString *)key;
- (void)BZ_setObject:(nullable id)anObject forKey:(id)aKey;

@end

NS_ASSUME_NONNULL_END

#endif /* BZBLEUtils_h */
