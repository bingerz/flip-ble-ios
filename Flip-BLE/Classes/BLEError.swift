import Foundation

@available(iOS 13.0, *)
public enum BLEError: Error {
    case disconnected
    case gatt
    case scanFailed
    case invalidOperation(String)
    case underlying(Error)

    public init(_ error: Error) {
        let nsError = error as NSError
        switch BZBLEErrorCode(rawValue: nsError.code) {
        case .disconnected:
            self = .disconnected
        case .gattError:
            self = .gatt
        case .scanFail:
            self = .scanFailed
        case .other:
            self = .invalidOperation(nsError.localizedDescription)
        default:
            self = .underlying(error)
        }
    }
}

final class ResumeGate {
    private let lock = NSLock()
    private var resumed = false

    func run(_ body: () -> Void) {
        lock.lock()
        if resumed {
            lock.unlock()
            return
        }
        resumed = true
        lock.unlock()
        body()
    }
}
