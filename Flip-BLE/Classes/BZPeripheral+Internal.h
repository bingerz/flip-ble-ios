//
//  BZPeripheral+Internal.h
//  Flip-BLE
//

#ifndef BZPeripheral_Internal_h
#define BZPeripheral_Internal_h

#import "BZPeripheral.h"

NS_ASSUME_NONNULL_BEGIN

@interface BZPeripheral ()

- (NSMutableArray *)discoverBlocks;
- (NSMutableArray *)serviceBlocks;
- (NSMutableDictionary *)charactBlocks;
- (NSMutableArray *)rssiBlocks;
- (NSMutableDictionary *)readBlocks;
- (NSMutableDictionary *)writBlocks;
- (NSMutableDictionary *)notifyStateBlocks;
- (NSMutableDictionary *)notifyValueBlocks;
- (NSMutableDictionary *)indicateStateBlocks;
- (NSMutableDictionary *)indicateValueBlocks;

- (void)cleanCallbacks;

@end

NS_ASSUME_NONNULL_END

#endif /* BZPeripheral_Internal_h */
