# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flip-BLE is an iOS Bluetooth Low Energy (BLE) framework built on top of CoreBluetooth, designed to simplify and stabilize BLE operations. It's distributed as a CocoaPods pod with iOS 10.0+ deployment target.

## Build and Development Commands

### Running the Example App
```bash
cd Example
pod install
```

Then open `Example/Flip-BLE.xcworkspace` in Xcode.

### Pod Linting
```bash
pod lib lint Flip-BLE.podspec
```

## Architecture

### Core Components

**BZCentralManager** (Singleton)
- Manages the CBCentralManager lifecycle (start, restart, destroy)
- Handles BLE scanning with `startScanWithServices:allowDup:` and `stopScan`
- Manages peripheral connections via `connectPeripheral:` and `cancelPeripheral:`
- Coordinates multiple peripherals through `BZMultiplePeripheralController`
- Key pattern: All BLE operations are dispatched to main thread via `runOnMainThread:`

**BZPeripheral**
- Wraps CBPeripheral with state machine (Disconnected -> Connecting -> Connected -> Discovering -> Discovered)
- Manages service and characteristic discovery callbacks
- Provides convenient methods for read/write/notify/indicate operations
- Maintains separate callback dictionaries for each operation type
- All callbacks are cleaned on disconnect

**BZPeripheralController**
- Created per-operation, not persisted
- Uses fluent interface: `[[controller withUUID:serviceUUID charact:charactUUID] readCharact:callback]`
- Validates characteristic properties before operations (e.g., checks CBCharacteristicPropertyRead)
- Handles callback routing through nested dictionaries: `[serviceUUID][charactUUID]`

**BZMultiplePeripheralController** (Singleton)
- Stores all connected peripherals by UUID string
- Handles batch operations (disconnect all, remove all)

### Delegate Protocols

- **BZScanDelegate**: Receives discovered peripherals during scanning
- **BZCentralStateDelegate**: Receives central manager state changes (powered on/off)
- **BZConnectStateDelegate**: Receives peripheral connection lifecycle events

### Callback Organization

Callbacks are stored in nested dictionaries:
- Read/Notify/Indicate callbacks: `NSMutableDictionary[CBUUID][CBUUID] -> NSMutableArray`
- Discover callbacks: Flat `NSMutableArray`

### Thread Safety

The framework uses `[BZCentralManager runOnMainThread:]` to ensure all CoreBluetooth operations execute on the main thread, despite the central manager being initialized on a background queue.

### State Machine

BZPeripheralState progression:
1. Disconnected (initial)
2. Connecting (during `connectPeripheral:`)
3. Connected (after `didConnectPeripheral`)
4. Discovering (during service/characteristic discovery)
5. Discovered (after all characteristics found)

### Error Handling

Custom errors via `BZBLEError` with error codes like `ErrorCodeDisconnected`. Errors are passed through callbacks, not thrown.

## Common Patterns

### Connecting and Discovering
```objc
// 1. Scan and receive via didScanning: delegate
// 2. Connect with delegate
peripheral.connectStateDelegate = self;
[centralManager addPeripheral:peripheral];
[peripheral connect];

// 3. Discover services in didConnected: delegate
[peripheral discoverServices:^(BZPeripheral *p, NSError *e) {
    // Services discovered, characteristics auto-discovered
}];
```

### Characteristic Operations
```objc
// Read with CBUUID objects
[peripheral readWithUUID:serviceUUID charactUUID:charactUUID callback:^(CBCharacteristic *c, NSError *e) {
    // Handle result
}];

// Write with string UUIDs
[peripheral writeWithUUIDString:@"180F" charactUUID:@"2A19" value:data callback:^(CBCharacteristic *c, NSError *e) {
    // Write complete
}];

// Set notify with separate state and value callbacks
[peripheral setNotifyWithUUIDString:serviceUUID charactUUID:charactUUID enable:YES
    stateCallback:^(CBCharacteristic *c, NSError *e) {
        // Notification state changed
    }
    valueCallback:^(CBCharacteristic *c, NSError *e) {
        // Received notification value
    }];
```

### Indicate vs Notify

Indicate operations are nearly identical to Notify but use:
- `setIndicateWithCharact:enable:stateCallback:valueCallback:`
- `indicateStateBlocks` / `indicateValueBlocks` dictionaries
- Checks `CBCharacteristicPropertyIndicate` instead of `CBCharacteristicPropertyNotify`

## File Structure

- `Flip-BLE/Classes/`: All framework source files (Objective-C)
- `Example/`: Demo app showing usage patterns
- `Flip-BLE.podspec`: Pod specification (version 0.4.1)
