import Foundation

struct RPCResponse: Codable {
    let result: RPCRateLimitsResponse?
    let error: RPCErrorMessage?
}

struct RPCErrorMessage: Codable {
    let code: Int?
    let message: String
}

struct RPCRateLimitsResponse: Codable {
    struct RateLimitWindow: Codable {
        let usedPercent: Double
        let windowDurationMins: Int?
        let resetsAt: Date?
    }
    struct RateLimits: Codable {
        let primary: RateLimitWindow
        let secondary: RateLimitWindow
    }
    let rateLimits: RateLimits
}

actor CodexRPCClient {
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    nonisolated func parseRateLimitsResponse(_ data: Data) throws -> UsageSnapshot {
        let decoded: RPCResponse
        do {
            decoded = try decoder.decode(RPCResponse.self, from: data)
        } catch {
            throw UsageError.decodeFailed(error.localizedDescription)
        }

        if let error = decoded.error {
            throw UsageError.rpcFailed(error.message)
        }
        guard let result = decoded.result else {
            throw UsageError.rpcFailed("Missing result")
        }
        return UsageSnapshot(
            primary: UsageWindow(
                usedPercent: result.rateLimits.primary.usedPercent,
                windowMinutes: result.rateLimits.primary.windowDurationMins,
                resetsAt: result.rateLimits.primary.resetsAt
            ),
            secondary: UsageWindow(
                usedPercent: result.rateLimits.secondary.usedPercent,
                windowMinutes: result.rateLimits.secondary.windowDurationMins,
                resetsAt: result.rateLimits.secondary.resetsAt
            ),
            fetchedAt: Date()
        )
    }
}
