import Foundation

protocol CodexCLIExecutor: Sendable {
    func execute() throws -> Process
    var isInstalled: Bool { get }
}

struct DefaultCodexCLIExecutor: CodexCLIExecutor {
    func execute() throws -> Process {
        let process = Process()

        if let executablePath = resolveCodexExecutable() {
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = ["-s", "read-only", "-a", "untrusted", "app-server"]
        } else {
            // Fall back to PATH resolution; `CodexRPCClient` will report
            // `cliNotFound` via `isInstalled` if this cannot be resolved.
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["codex", "-s", "read-only", "-a", "untrusted", "app-server"]
        }

        return process
    }

    var isInstalled: Bool {
        resolveCodexExecutable() != nil
    }

    /// Returns the first valid `codex` executable path from:
    /// 1. The `codexCLIPath` `UserDefaults` override.
    /// 2. Common install locations for Homebrew, `~/.local/bin`, and system paths.
    /// 3. The first path returned by `/usr/bin/env which codex`.
    func resolveCodexExecutable() -> String? {
        if let overridePath = resolveUserDefaultsOverride() {
            return overridePath
        }

        if let commonPath = resolveCommonInstallLocation() {
            return commonPath
        }

        return resolveViaWhich()
    }

    // MARK: - Resolution helpers

    private func resolveUserDefaultsOverride() -> String? {
        let override = UserDefaults.standard.string(forKey: "codexCLIPath")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let override, !override.isEmpty else { return nil }

        return validatedOverridePath(override)
    }

    private func validatedOverridePath(_ path: String) -> String? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/"),
              (trimmed as NSString).lastPathComponent == "codex",
              trimmed.rangeOfCharacter(from: .controlCharacters) == nil else {
            return nil
        }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: trimmed, isDirectory: &isDir),
              !isDir.boolValue else {
            return nil
        }
        return trimmed
    }

    private func resolveCommonInstallLocation() -> String? {
        let candidates = [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            NSString(string: "~/.local/bin/codex").expandingTildeInPath,
            "/usr/bin/codex",
        ]
        return candidates.first(where: fileExistsAtPath)
    }

    private func resolveViaWhich() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["which", "codex"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()

        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: output, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if task.terminationStatus == 0 && !path.isEmpty && fileExistsAtPath(path) {
            return path
        }
        return nil
    }

    private func fileExistsAtPath(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
}

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

protocol CodexRPCClientProtocol: Sendable {
    func fetchUsage() async throws -> UsageSnapshot
}

actor CodexRPCClient: CodexRPCClientProtocol {
    private let executor: CodexCLIExecutor
    private var currentProcess: Process?

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    init(executor: CodexCLIExecutor = DefaultCodexCLIExecutor()) {
        self.executor = executor
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard executor.isInstalled else {
            throw UsageError.cliNotFound
        }

        let process = try executor.execute()
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        currentProcess = process
        defer {
            if process.isRunning {
                process.terminate()
            }
            currentProcess = nil
        }

        try process.run()

        let initializeRequest: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 0,
            "method": "initialize",
            "params": [
                "clientInfo": [
                    "name": "Codex-Usage",
                    "version": "1.0.0"
                ]
            ]
        ]

        let initializedNotification: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "initialized"
        ]

        let rateLimitsRequest: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "account/rateLimits/read"
        ]

        for request in [initializeRequest, initializedNotification, rateLimitsRequest] {
            let payload = try JSONSerialization.data(withJSONObject: request, options: [])
            stdin.fileHandleForWriting.write(payload)
            stdin.fileHandleForWriting.write(Data("\n".utf8))
        }
        stdin.fileHandleForWriting.closeFile()

        let stdoutData: Data
        do {
            stdoutData = try await readAllData(from: stdout, timeout: 8)
        } catch {
            process.terminate()
            throw error
        }

        process.waitUntilExit()

        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0 {
            let errorText = String(data: stderrData, encoding: .utf8) ?? ""
            let lowercased = errorText.lowercased()
            if lowercased.contains("not authenticated") || lowercased.contains("login") {
                throw UsageError.notAuthenticated
            }
            throw UsageError.rpcFailed(
                errorText.isEmpty ? "Process exited with \(process.terminationStatus)" : errorText
            )
        }

        guard let responseLine = extractResponseLine(for: 1, from: stdoutData) else {
            throw UsageError.rpcFailed("Missing rate limits response")
        }

        return try parseRateLimitsResponse(responseLine)
    }

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

    internal nonisolated func extractResponseLine(for id: Int, from data: Data) -> Data? {
        guard let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  let lineData = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let lineId = json["id"] as? Int,
                  lineId == id else {
                continue
            }
            return lineData
        }
        return nil
    }

    private func readAllData(from pipe: Pipe, timeout: TimeInterval) async throws -> Data {
        try await withTimeout(seconds: timeout) {
            var data = Data()
            for try await byte in pipe.fileHandleForReading.bytes {
                data.append(byte)
            }
            return data
        }
    }

    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw UsageError.rpcFailed("timeout")
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
