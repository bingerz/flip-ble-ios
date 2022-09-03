//
//  BZMultiplePeripheralController.m
//  Flip-BLE
//
//  Created by Hanson on 2022/8/18.
//

#import <Foundation/Foundation.h>
#import "BZBLEUtils.h"
#import "CBObject+BZAddition.h"
#import "BZMultiplePeripheralController.h"

@implementation BZMultiplePeripheralController{
    NSLock *dicLock;
    NSMutableDictionary *peripherals;
}

static BZMultiplePeripheralController *sharedInstance;

+ (instancetype)sharedInstance{
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[[self class] alloc] init];
    });
    
    return sharedInstance;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        dicLock = [[NSLock alloc] init];
        peripherals = [NSMutableDictionary dictionaryWithCapacity:7];
    }
    return self;
}

- (void)dealloc{
    [dicLock unlock];
    dicLock = nil;
    [peripherals removeAllObjects];
    peripherals = nil;
}

- (void)addPeripheral:(BZPeripheral *)peripheral{
    if (!peripheral) {
        return;
    }
    if ([peripherals BZ_isValidForKey:peripheral.UUIDString]) {
        NSLog(@"addPeripheral peripheral is existed %@", peripheral.UUIDString);
        return;
    }
    [dicLock lock];
    peripherals[peripheral.UUIDString] = peripheral;
    [dicLock unlock];
}

- (void)removePeripheral:(BZPeripheral *)peripheral{
    if (!peripheral || ![peripherals BZ_isValidForKey:peripheral.UUIDString]) {
        NSLog(@"removePeripheral peripheral %@", peripheral ? @"not exist" : @"is nil");
        return;
    }
    [dicLock lock];
    [peripherals removeObjectForKey:peripheral.UUIDString];
    [dicLock unlock];
}

- (void)removeAllPeripheral{
    [dicLock lock];
    [peripherals removeAllObjects];
    [dicLock unlock];
}

- (BZPeripheral *)getPeripheral:(NSString *)key{
    if ([peripherals BZ_isValidForKey:key]) {
        return peripherals[key];
    }
    return nil;
}

- (void)disconnectAllPeripheral{
    [dicLock lock];
    for(NSString *key in peripherals) {
        BZPeripheral *peripheral = peripherals[key];
        [peripheral disconnect];
    }
    [dicLock unlock];
}

- (NSArray *)getPeripherals{
    return [peripherals allValues];
}

@end
