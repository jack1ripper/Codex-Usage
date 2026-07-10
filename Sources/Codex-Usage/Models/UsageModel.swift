import Foundation

struct UsageWindow: Codable, Equatable, Sendable {
    let usedPercent: Double
    let windowMinutes: Int?
    let resetsAt: Date?
    
    var remainingPercent: Double {
        max(0, 100 - usedPercent)
    }
    
    var remainingRatio: Double {
        remainingPercent / 100
    }
}

struct UsageSnapshot: Equatable, Sendable {
    let primary: UsageWindow   // 5-hour window
    let secondary: UsageWindow // weekly window
    let fetchedAt: Date
}

enum UsageError: Error, Equatable, Sendable {
    case cliNotFound
    case notAuthenticated
    case rpcFailed(String)
    case decodeFailed(String)
}
