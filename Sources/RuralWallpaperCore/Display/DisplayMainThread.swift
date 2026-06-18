import Foundation

enum DisplayMainThread {
    static func sync<T>(_ work: @escaping @Sendable () throws -> T) rethrows -> T {
        if Thread.isMainThread {
            return try work()
        }

        return try DispatchQueue.main.sync {
            try work()
        }
    }
}
