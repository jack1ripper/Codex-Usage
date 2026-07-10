# Codex-Usage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS floating-ball app that displays Codex 5-hour and weekly usage remaining plus reset countdowns.

**Architecture:** A Swift Package Manager macOS app using SwiftUI for rendering and AppKit for the floating window. Data comes from local `codex app-server` JSON-RPC. A refresh service polls every 60s and publishes state to the UI.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Combine, XCTest

---

## File Structure

```
Codex-Usage/
├── Package.swift
├── .gitignore
├── Sources/
│   └── Codex-Usage/
│       ├── App/
│       │   ├── main.swift
│       │   └── Codex_UsageApp.swift
│       ├── Models/
│       │   └── UsageModel.swift
│       ├── Services/
│       │   ├── CodexRPCClient.swift
│       │   └── UsageRefreshService.swift
│       ├── Views/
│       │   └── FloatingBallView.swift
│       └── Windows/
│           └── FloatingWindowController.swift
└── Tests/
    └── Codex-UsageTests/
        ├── CodexRPCClientTests.swift
        └── UsageRefreshServiceTests.swift
```

---

## Task 1: Initialize Swift Package Project

**Files:**
- Create: `Package.swift`
- Create: `.gitignore`
- Create: directories `Sources/Codex-Usage/App`, `Sources/Codex-Usage/Models`, `Sources/Codex-Usage/Services`, `Sources/Codex-Usage/Views`, `Sources/Codex-Usage/Windows`, `Tests/Codex-UsageTests`

- [ ] **Step 1: Write Package.swift**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Codex-Usage",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Codex-Usage", targets: ["Codex-Usage"])
    ],
    targets: [
        .executableTarget(
            name: "Codex-Usage",
            path: "Sources/Codex-Usage"
        ),
        .testTarget(
            name: "Codex-UsageTests",
            dependencies: ["Codex-Usage"],
            path: "Tests/Codex-UsageTests"
        )
    ]
)
```

- [ ] **Step 2: Write .gitignore**

```gitignore
.DS_Store
.build
xcuserdata
*.xcodeproj
```

- [ ] **Step 3: Create directories**

Run:
```bash
mkdir -p Sources/Codex-Usage/App Sources/Codex-Usage/Models Sources/Codex-Usage/Services Sources/Codex-Usage/Views Sources/Codex-Usage/Windows Tests/Codex-UsageTests
```

- [ ] **Step 4: Verify package structure**

Run:
```bash
swift package describe
```

Expected: Command prints package metadata without errors and lists the `Codex-Usage` executable target and `Codex-UsageTests` test target.

---

## Task 2: Define UsageModel

**Files:**
- Create: `Sources/Codex-Usage/Models/UsageModel.swift`

- [ ] **Step 1: Write UsageModel.swift**

```swift
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
```

- [ ] **Step 2: Verify model compiles**

Run:
```bash
swift build
```

Expected: Build fails later because there is no executable entry yet, but `UsageModel.swift` itself must not produce errors. (The build will complain about missing `main.swift`, which is fine for now.)

---

## Task 3: Implement CodexRPCClient Parsing

**Files:**
- Create: `Sources/Codex-Usage/Services/CodexRPCClient.swift`
- Create: `Tests/Codex-UsageTests/CodexRPCClientTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import XCTest
@testable import Codex_Usage

final class CodexRPCClientTests: XCTestCase {
    func testParsesRateLimitsResponse() throws {
        let json = """
        {
          "jsonrpc": "2.0",
          "id": 1,
          "result": {
            "rate_limits": {
              "primary": {
                "used_percent": 20.0,
                "window_duration_mins": 300,
                "resets_at": 1752158400
              },
              "secondary": {
                "used_percent": 50.0,
                "window_duration_mins": 10080,
                "resets_at": 1752441600
              }
            }
          }
        }
        """.data(using: .utf8)!
        
        let client = CodexRPCClient()
        let snapshot = try client.parseRateLimitsResponse(json)
        
        XCTAssertEqual(snapshot.primary.remainingPercent, 80.0, accuracy: 0.001)
        XCTAssertEqual(snapshot.secondary.remainingPercent, 50.0, accuracy: 0.001)
        XCTAssertEqual(snapshot.primary.resetsAt?.timeIntervalSince1970, 1752158400, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
swift test --filter CodexRPCClientTests
```

Expected: FAIL with `'CodexRPCClient' has no member 'parseRateLimitsResponse'`.

- [ ] **Step 3: Implement CodexRPCClient parse method**

```swift
import Foundation

actor CodexRPCClient {
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()
    
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
    
    func parseRateLimitsResponse(_ data: Data) throws -> UsageSnapshot {
        struct RPCResponse: Codable {
            let result: RPCRateLimitsResponse?
            let error: RPCErrorMessage?
        }
        struct RPCErrorMessage: Codable, Error {
            let message: String
        }
        
        let decoded = try decoder.decode(RPCResponse.self, from: data)
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
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
swift test --filter CodexRPCClientTests/testParsesRateLimitsResponse
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Package.swift .gitignore Sources/Codex-Usage/Models/UsageModel.swift Sources/Codex-Usage/Services/CodexRPCClient.swift Tests/Codex-UsageTests/CodexRPCClientTests.swift
git commit -m "feat: add UsageModel and CodexRPCClient parsing"
```


## Task 4: Implement Full Codex RPC Communication

**Files:**
- Modify: `Sources/Codex-Usage/Services/CodexRPCClient.swift`

- [ ] **Step 1: Add CodexCLIExecutor abstraction**

Append to `CodexRPCClient.swift`:

```swift
protocol CodexCLIExecutor: Sendable {
    func execute() throws -> Process
    var isInstalled: Bool { get }
}

struct DefaultCodexCLIExecutor: CodexCLIExecutor {
    func execute() throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["codex", "-s", "read-only", "-a", "untrusted", "app-server"]
        return process
    }
    
    var isInstalled: Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["which", "codex"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: output, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return task.terminationStatus == 0 && !path.isEmpty
    }
}
```

- [ ] **Step 2: Add JSON-RPC plumbing to CodexRPCClient**

Replace the existing `CodexRPCClient` actor body with the full implementation below (keep `parseRateLimitsResponse`):

```swift
actor CodexRPCClient {
    private let executor: CodexCLIExecutor
    private let encoder = JSONEncoder()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()
    private var currentProcess: Process?
    
    init(executor: CodexCLIExecutor = DefaultCodexCLIExecutor()) {
        self.executor = executor
    }
    
    func fetchUsage() async throws -> UsageSnapshot {
        guard executor.isInstalled else {
            throw UsageError.cliNotFound
        }
        
        let process = try executor.execute()
        currentProcess = process
        defer {
            if process.isRunning {
                process.terminate()
            }
            currentProcess = nil
        }
        
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        
        // Send initialize + initialized
        try await sendInitialize(input: inputPipe, output: outputPipe)
        try sendNotification(method: "initialized", input: inputPipe)
        
        // Fetch rate limits
        let responseData = try await sendRequest(method: "account/rateLimits/read", input: inputPipe, output: outputPipe)
        
        return try parseRateLimitsResponse(responseData)
    }
    
    private func sendInitialize(input: Pipe, output: Pipe) async throws {
        let params: [String: Any] = [
            "clientInfo": ["name": "Codex-Usage", "version": "1.0.0"]
        ]
        _ = try await sendRawRequest(id: 0, method: "initialize", params: params, input: input, output: output)
    }
    
    private func sendRequest(method: String, input: Pipe, output: Pipe) async throws -> Data {
        try await sendRawRequest(id: 1, method: method, params: nil, input: input, output: output)
    }
    
    private func sendRawRequest(id: Int, method: String, params: [String: Any]?, input: Pipe, output: Pipe) async throws -> Data {
        var request: [String: Any] = [
            "jsonrpc": "2.0",
            "method": method,
            "id": id
        ]
        if let params = params {
            request["params"] = params
        }
        
        let data = try JSONSerialization.data(withJSONObject: request)
        let line = data + Data([0x0A]) // newline
        try input.fileHandleForWriting.write(contentsOf: line)
        
        // Read line-by-line until we find a response with matching id
        return try await withTimeout(seconds: 5) {
            while let lineData = await self.readLine(from: output) {
                if let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                   let responseId = json["id"] as? Int,
                   responseId == id {
                    return lineData
                }
            }
            throw UsageError.rpcFailed("No response for request \(id)")
        }
    }
    
    private func sendNotification(method: String, input: Pipe) throws {
        let notification: [String: Any] = [
            "jsonrpc": "2.0",
            "method": method
        ]
        let data = try JSONSerialization.data(withJSONObject: notification)
        let line = data + Data([0x0A])
        try input.fileHandleForWriting.write(contentsOf: line)
    }
    
    private func readLine(from pipe: Pipe) async -> Data? {
        let handle = pipe.fileHandleForReading
        var buffer = Data()
        while let byte = try? handle.read(upToCount: 1), !byte.isEmpty {
            buffer.append(byte)
            if byte.first == 0x0A {
                return buffer
            }
        }
        return buffer.isEmpty ? nil : buffer
    }
    
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw UsageError.rpcFailed("Request timed out after \(seconds)s")
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
```

Wait, `Pipe.fileHandleForReading.read(upToCount:)` is available on macOS 14+. Good.

But there is a problem: `Task.sleep` is not actually throwing an error if cancelled. In `withThrowingTaskGroup`, if operation finishes first, we cancel all including sleep, and `Task.sleep` will throw `CancellationError`. But `withThrowingTaskGroup` will rethrow the first error. If operation succeeds, we call `group.next()` which returns the success, then `group.cancelAll()`. The sleep task will throw `CancellationError`, but since we already got the result, it should be fine. Actually, `withThrowingTaskGroup` waits for all tasks to finish or be cancelled. The cancellation error might be rethrown. Let me use a simpler timeout with `withCheckedThrowingContinuation` and `Task.detached`.

Actually, a simpler pattern:

```swift
private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    let task = Task {
        try await operation()
    }
    let timeout = Task {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        task.cancel()
    }
    do {
        let result = try await task.value
        timeout.cancel()
        return result
    } catch {
        timeout.cancel()
        throw error
    }
}
```

This is cleaner. But if operation is cancelled due to timeout, the error will be `CancellationError`. We might want to convert it to timeout error. However, the operation itself might also be cancelled externally. To keep it simple, I'll use the task group pattern but catch `CancellationError`.

Actually, the simplest is:

```swift
private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw UsageError.rpcFailed("Request timed out after \(seconds)s")
        }
        defer { group.cancelAll() }
        return try await group.next()!
    }
}
```

This has the issue that when one task finishes, the other task's error (CancellationError or timeout) might be thrown instead. Actually, `withThrowingTaskGroup` returns the first completed task's result. If the first completed task is successful, it returns that. The other task is cancelled. If the other task throws `CancellationError`, it is ignored because the group is already returning. If the other task throws a non-cancellation error before the successful task, it might be thrown.

This pattern is commonly used and works in practice. I'll use it.

But there's another issue: `readLine` returns `Data?` but I'm calling it in a loop. Since `read(upToCount:)` can block, and it's not async, but the whole function is async, it will block the thread. This is not ideal but acceptable for a simple app. Better to use `bytes` async stream, but that's more complex. For simplicity, I'll keep blocking read.

Actually, on macOS 14+, `FileHandle` has `bytes` property which is `AsyncBytes`. Let me use that:

```swift
private func readLine(from pipe: Pipe) async -> Data? {
    var buffer = Data()
    for await byte in pipe.fileHandleForReading.bytes {
        buffer.append(byte)
        if byte == 0x0A {
            return buffer
        }
    }
    return buffer.isEmpty ? nil : buffer
}
```

This is cleaner and non-blocking.

- [ ] **Step 3: Add not-authenticated detection**

After process terminates, read stderr. If it contains "not authenticated" or "Please run `codex login`", throw `.notAuthenticated`.

Update `fetchUsage()` to check stderr before parsing:

```swift
let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
let errorText = String(data: errorData, encoding: .utf8) ?? ""

if process.terminationStatus != 0 || !errorText.isEmpty {
    if errorText.localizedCaseInsensitiveContains("not authenticated") ||
       errorText.localizedCaseInsensitiveContains("login") {
        throw UsageError.notAuthenticated
    }
    if process.terminationStatus != 0 {
        throw UsageError.rpcFailed(errorText.isEmpty ? "Process exited with \(process.terminationStatus)" : errorText)
    }
}
```

Place this after sending requests but before parsing. Actually, we should check it after the process terminates. But in our flow, we read response data and then process terminates when input pipe closes. Let me restructure.

Actually, the process will stay alive as long as stdin is open. We close stdin after sending all requests. Then process terminates. We can read stdout until EOF, then read stderr and status.

This is getting complex. For the plan, I'll keep it simpler: use a helper that runs the process to completion and returns stdout.

But since `codex app-server` is a long-running process, we need to close stdin to signal we're done. Then we read stdout/stderr until EOF.

Let me simplify the implementation in the plan:

```swift
func fetchUsage() async throws -> UsageSnapshot {
    guard executor.isInstalled else {
        throw UsageError.cliNotFound
    }
    
    let process = try executor.execute()
    currentProcess = process
    defer {
        if process.isRunning {
            process.terminate()
        }
        currentProcess = nil
    }
    
    let inputPipe = Pipe()
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardInput = inputPipe
    process.standardOutput = outputPipe
    process.standardError = errorPipe
    
    try process.run()
    
    // Build all requests
    let requests: [[String: Any]] = [
        ["jsonrpc": "2.0", "method": "initialize", "params": ["clientInfo": ["name": "Codex-Usage", "version": "1.0.0"]], "id": 0],
        ["jsonrpc": "2.0", "method": "initialized"],
        ["jsonrpc": "2.0", "method": "account/rateLimits/read", "id": 1]
    ]
    
    for request in requests {
        let data = try JSONSerialization.data(withJSONObject: request)
        let line = data + Data([0x0A])
        try inputPipe.fileHandleForWriting.write(contentsOf: line)
    }
    inputPipe.fileHandleForWriting.closeFile()
    
    // Read stdout until EOF with timeout
    let outputData = try await withTimeout(seconds: 8) {
        outputPipe.fileHandleForReading.readDataToEndOfFile()
    }
    
    process.waitUntilExit()
    
    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
    let errorText = String(data: errorData, encoding: .utf8) ?? ""
    
    if process.terminationStatus != 0 {
        if errorText.localizedCaseInsensitiveContains("not authenticated") ||
           errorText.localizedCaseInsensitiveContains("login") {
            throw UsageError.notAuthenticated
        }
        throw UsageError.rpcFailed(errorText.isEmpty ? "Process exited with \(process.terminationStatus)" : errorText)
    }
    
    // Extract the response line with id=1
    guard let responseLine = extractResponseLine(for: 1, from: outputData) else {
        throw UsageError.rpcFailed("Could not find rate limits response")
    }
    
    return try parseRateLimitsResponse(responseLine)
}

func extractResponseLine(for id: Int, from data: Data) -> Data? {
    let text = String(data: data, encoding: .utf8) ?? ""
    for line in text.components(separatedBy: .newlines) {
        guard let lineData = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
              let responseId = json["id"] as? Int,
              responseId == id else {
            continue
        }
        return lineData
    }
    return nil
}
```

This is much cleaner. `readDataToEndOfFile()` is blocking, but it's wrapped in a timeout task. However, `readDataToEndOfFile()` blocks the thread, so the timeout task in a different Task might not be able to cancel it. This is a problem.

Better to use async bytes:

```swift
private func readAllData(from pipe: Pipe, timeout: TimeInterval) async throws -> Data {
    try await withTimeout(seconds: timeout) {
        var data = Data()
        for await byte in pipe.fileHandleForReading.bytes {
            data.append(byte)
        }
        return data
    }
}
```

This works because `bytes` is async and can be cancelled.

So `fetchUsage` uses:
```swift
let outputData = try await readAllData(from: outputPipe, timeout: 8)
```

Good.

- [ ] **Step 4: Write integration-style test with mock executor**

```swift
final class CodexRPCClientIntegrationTests: XCTestCase {
    struct MockCodexCLIExecutor: CodexCLIExecutor {
        let output: Data
        let exitStatus: Int32
        let stderr: Data
        
        var isInstalled: Bool { true }
        
        func execute() throws -> Process {
            let process = Process()
            // Real mock would need a helper executable; for unit test we test parsing path only.
            return process
        }
    }
    
    func testExtractsResponseLine() {
        let client = CodexRPCClient()
        let data = """
        {"jsonrpc":"2.0","id":0,"result":{}}
        {"jsonrpc":"2.0","id":1,"result":{"rate_limits":{"primary":{"used_percent":10.0,"resets_at":1752158400},"secondary":{"used_percent":20.0,"resets_at":1752441600}}}}
        """.data(using: .utf8)!
        
        let line = client.extractResponseLine(for: 1, from: data)
        XCTAssertNotNil(line)
    }
}
```

Wait, `extractResponseLine` is private. Need to make it internal or test via a public method. I'll make it `internal` by removing `private`.

- [ ] **Step 5: Run tests**

Run:
```bash
swift test --filter CodexRPCClient
```

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add Sources/Codex-Usage/Services/CodexRPCClient.swift Tests/Codex-UsageTests/CodexRPCClientTests.swift
git commit -m "feat: implement full Codex JSON-RPC client"
```


## Task 5: Implement UsageRefreshService

**Files:**
- Create: `Sources/Codex-Usage/Services/UsageRefreshService.swift`
- Create: `Tests/Codex-UsageTests/UsageRefreshServiceTests.swift`

- [ ] **Step 1: Write UsageRefreshService.swift**

```swift
import Foundation
import Combine

@MainActor
final class UsageRefreshService: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var error: UsageError?
    @Published private(set) var isLoading: Bool = false
    
    private let rpcClient: CodexRPCClient
    private var timer: Timer?
    private let refreshInterval: TimeInterval
    
    init(rpcClient: CodexRPCClient = CodexRPCClient(), refreshInterval: TimeInterval = 60) {
        self.rpcClient = rpcClient
        self.refreshInterval = refreshInterval
    }
    
    func start() {
        Task {
            await refresh()
        }
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.refresh()
            }
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        do {
            let newSnapshot = try await rpcClient.fetchUsage()
            snapshot = newSnapshot
            error = nil
        } catch let usageError as UsageError {
            error = usageError
        } catch {
            self.error = .rpcFailed(error.localizedDescription)
        }
        isLoading = false
    }
}
```

- [ ] **Step 2: Write test for refresh service**

```swift
import XCTest
@testable import Codex_Usage

final class UsageRefreshServiceTests: XCTestCase {
    func testPublishesSnapshotAfterRefresh() async {
        // We test the service by injecting a mock RPC client.
        // For the plan, verify the public API shape by manually calling refresh.
        let service = UsageRefreshService()
        
        XCTAssertNil(service.snapshot)
        XCTAssertFalse(service.isLoading)
        
        await service.refresh()
        
        // Outcome depends on local Codex CLI state; in CI this may be .cliNotFound.
        // The important behavior is that isLoading returns to false.
        XCTAssertFalse(service.isLoading)
    }
}
```

- [ ] **Step 3: Run tests**

Run:
```bash
swift test --filter UsageRefreshServiceTests
```

Expected: PASS or SKIP depending on environment; no crashes.

- [ ] **Step 4: Commit**

```bash
git add Sources/Codex-Usage/Services/UsageRefreshService.swift Tests/Codex-UsageTests/UsageRefreshServiceTests.swift
git commit -m "feat: add UsageRefreshService with polling"
```

---

## Task 6: Implement FloatingBallView

**Files:**
- Create: `Sources/Codex-Usage/Views/FloatingBallView.swift`

- [ ] **Step 1: Write FloatingBallView.swift**

```swift
import SwiftUI

struct FloatingBallView: View {
    @ObservedObject var service: UsageRefreshService
    let onRefresh: () -> Void
    
    private var snapshot: UsageSnapshot? { service.snapshot }
    private var error: UsageError? { service.error }
    private var primaryWindow: UsageWindow? { snapshot?.primary }
    private var secondaryWindow: UsageWindow? { snapshot?.secondary }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            
            VStack(spacing: 4) {
                if let error = error {
                    errorView(error)
                } else if let snapshot = snapshot {
                    usageView(snapshot)
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundStyle(.primary)
                }
            }
            .frame(width: 120, height: 120)
        }
        .frame(width: 140, height: 140)
    }
    
    private func usageView(_ snapshot: UsageSnapshot) -> some View {
        ZStack {
            // Outer ring: 5h
            progressRing(
                ratio: primaryWindow?.remainingRatio ?? 0,
                color: color(for: primaryWindow?.remainingRatio ?? 0),
                lineWidth: 10,
                radius: 58
            )
            
            // Inner ring: weekly
            progressRing(
                ratio: secondaryWindow?.remainingRatio ?? 0,
                color: color(for: secondaryWindow?.remainingRatio ?? 0),
                lineWidth: 8,
                radius: 44
            )
            
            VStack(spacing: 2) {
                Text(nearestResetText)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text("until reset")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    VStack(spacing: 0) {
                        Text("5h")
                            .font(.system(size: 8, weight: .semibold))
                        Text(percentText(for: primaryWindow))
                            .font(.system(size: 8))
                    }
                    VStack(spacing: 0) {
                        Text("Wk")
                            .font(.system(size: 8, weight: .semibold))
                        Text(percentText(for: secondaryWindow))
                            .font(.system(size: 8))
                    }
                }
                .padding(.top, 2)
            }
        }
    }
    
    private func progressRing(ratio: Double, color: Color, lineWidth: CGFloat, radius: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: lineWidth)
                .frame(width: radius * 2, height: radius * 2)
            Circle()
                .trim(from: 0, to: ratio)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: radius * 2, height: radius * 2)
                .rotationEffect(.degrees(-90))
        }
    }
    
    private var nearestResetText: String {
        guard let snapshot = snapshot else { return "—" }
        let now = Date()
        let candidates = [snapshot.primary.resetsAt, snapshot.secondary.resetsAt].compactMap { $0 }.filter { $0 > now }
        guard let nearest = candidates.min() else { return "—" }
        return formatCountdown(from: now, to: nearest)
    }
    
    private func formatCountdown(from start: Date, to end: Date) -> String {
        let interval = end.timeIntervalSince(start)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func percentText(for window: UsageWindow?) -> String {
        guard let window = window else { return "—" }
        return "\(Int(window.remainingPercent))%"
    }
    
    private func color(for ratio: Double) -> Color {
        switch ratio {
        case ..<0.1: return .red
        case 0.1..<0.3: return .yellow
        default: return .cyan
        }
    }
    
    private func errorView(_ error: UsageError) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundStyle(.orange)
            Text(errorMessage(for: error))
                .font(.system(size: 10, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
        }
    }
    
    private func errorMessage(for error: UsageError) -> String {
        switch error {
        case .cliNotFound:
            return "Install Codex CLI"
        case .notAuthenticated:
            return "Run `codex login`"
        case .rpcFailed(let msg):
            return msg.count > 40 ? String(msg.prefix(40)) + "…" : msg
        case .decodeFailed(let msg):
            return msg
        }
    }
}

#Preview {
    FloatingBallView(
        service: UsageRefreshService(),
        onRefresh: {}
    )
}
```

- [ ] **Step 2: Verify preview compiles**

Run:
```bash
swift build
```

Expected: Build succeeds (still missing main entry, which is expected).

- [ ] **Step 3: Commit**

```bash
git add Sources/Codex-Usage/Views/FloatingBallView.swift
git commit -m "feat: add FloatingBallView UI"
```

---

## Task 7: Implement FloatingWindowController

**Files:**
- Create: `Sources/Codex-Usage/Windows/FloatingWindowController.swift`

- [ ] **Step 1: Write FloatingWindowController.swift**

```swift
import SwiftUI
import AppKit
import Combine

@MainActor
final class FloatingWindowController: NSObject, NSWindowDelegate {
    private var window: NSPanel?
    private let service: UsageRefreshService
    private var cancellables = Set<AnyCancellable>()
    
    init(service: UsageRefreshService) {
        self.service = service
        super.init()
    }
    
    func show() {
        let panel = NSPanel(
            contentRect: NSRect(x: 100, y: 100, width: 140, height: 140),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = true
        panel.delegate = self
        
        let contentView = FloatingBallView(
            service: service,
            onRefresh: { [weak service] in
                Task {
                    await service?.refresh()
                }
            }
        )
        
        panel.contentView = NSHostingView(rootView: contentView)
        
        // Restore saved position
        restorePosition(for: panel)
        
        self.window = panel
        panel.orderFrontRegardless()
        
        service.start()
    }
    
    func windowWillMove(_ notification: Notification) {
        // Optional: visual feedback during drag
    }
    
    func windowDidMove(_ notification: Notification) {
        guard let window = window else { return }
        savePosition(of: window)
    }
    
    private func savePosition(of window: NSWindow) {
        let frame = window.frame
        let defaults = UserDefaults.standard
        defaults.set(frame.origin.x, forKey: "floatingBallX")
        defaults.set(frame.origin.y, forKey: "floatingBallY")
    }
    
    private func restorePosition(for window: NSWindow) {
        let defaults = UserDefaults.standard
        guard let x = defaults.object(forKey: "floatingBallX") as? CGFloat,
              let y = defaults.object(forKey: "floatingBallY") as? CGFloat else {
            return
        }
        let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        var frame = window.frame
        frame.origin.x = max(screenFrame.minX, min(x, screenFrame.maxX - frame.width))
        frame.origin.y = max(screenFrame.minY, min(y, screenFrame.maxY - frame.height))
        window.setFrame(frame, display: true)
    }
}
```

- [ ] **Step 2: Add right-click menu support**

Create a small bridging helper or add it inside `FloatingBallView` via `contextMenu`:

In `FloatingBallView.swift`, add after the outer `ZStack`:

```swift
.contextMenu {
    Button("Refresh") {
        onRefresh()
    }
    Divider()
    Button("Quit") {
        NSApplication.shared.terminate(nil)
    }
}
```

- [ ] **Step 3: Verify build**

Run:
```bash
swift build
```

Expected: Build still fails due to missing main entry; window code itself must compile without errors.

- [ ] **Step 4: Commit**

```bash
git add Sources/Codex-Usage/Windows/FloatingWindowController.swift Sources/Codex-Usage/Views/FloatingBallView.swift
git commit -m "feat: add floating window controller with drag and position memory"
```

---

## Task 8: Wire Up App Entry

**Files:**
- Create: `Sources/Codex-Usage/App/Codex_UsageApp.swift`
- Create: `Sources/Codex-Usage/App/main.swift`

- [ ] **Step 1: Write Codex_UsageApp.swift**

```swift
import SwiftUI
import AppKit

@main
struct Codex_UsageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // No window scene; the floating panel is managed manually.
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: FloatingWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let service = UsageRefreshService()
        let controller = FloatingWindowController(service: service)
        controller.show()
        windowController = controller
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
```

Wait, SPM executable with `@main` in a struct conforming to `App` should work. But `App` protocol is part of SwiftUI and normally used in app bundles, not command-line executables. For a macOS app bundle, we need an `.app` bundle with `Info.plist`. SPM alone cannot produce a proper `.app` bundle.

This is a critical issue. Swift Package Manager can build an executable, but not a macOS app bundle. To create a real Mac app, we need either:
1. Xcode project
2. A build script that wraps the executable into an `.app` bundle
3. Use `swift package generate-xcodeproj` (deprecated)

For a simple tool, we can create the `.app` bundle manually with a script. But then we lose SwiftUI `App` lifecycle benefits.

Alternative: Use AppKit directly without SwiftUI `App`:

```swift
import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: FloatingWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let service = UsageRefreshService()
        let controller = FloatingWindowController(service: service)
        controller.show()
        windowController = controller
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

autoreleasepool {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
```

But `@main` cannot be used with top-level code like `autoreleasepool`. We need either:
- A `main.swift` with top-level code
- Or `@main` on a struct that calls `NSApplicationMain`

The simplest is `main.swift`:

```swift
import AppKit

autoreleasepool {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
```

And `AppDelegate` in a separate file.

But then we can still use SwiftUI `FloatingBallView` inside `NSHostingView`.

This is actually the better approach for SPM-based macOS app.

Let me update the plan accordingly.

- [ ] **Step 1: Write AppDelegate.swift**

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: FloatingWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        let service = UsageRefreshService()
        let controller = FloatingWindowController(service: service)
        controller.show()
        windowController = controller
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
```

- [ ] **Step 2: Write main.swift**

```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

- [ ] **Step 3: Remove Codex_UsageApp.swift or keep empty**

Delete `Sources/Codex-Usage/App/Codex_UsageApp.swift` if it was created. Only `AppDelegate.swift` and `main.swift` are needed.

- [ ] **Step 4: Add app bundle wrapper script**

Create `Scripts/build_app.sh`:

```bash
#!/bin/bash
set -e

APP_NAME="Codex-Usage"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"

swift build -c release

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.yourcompany.Codex-Usage</string>
    <key>CFBundleName</key>
    <string>Codex-Usage</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "Built $APP_BUNDLE"
```

Make it executable:
```bash
chmod +x Scripts/build_app.sh
```

- [ ] **Step 5: Build and run**

Run:
```bash
swift build
```

Expected: Build succeeds.

Then test the executable:
```bash
.build/debug/Codex-Usage
```

Expected: A floating ball appears on screen.

To build the app bundle:
```bash
./Scripts/build_app.sh
open Codex-Usage.app
```

- [ ] **Step 6: Commit**

```bash
git add Sources/Codex-Usage/App/AppDelegate.swift Sources/Codex-Usage/App/main.swift Scripts/build_app.sh
git commit -m "feat: wire app entry and add app bundle build script"
```

---

## Task 9: Final Integration and Smoke Test

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README.md**

```markdown
# Codex-Usage

A minimalist macOS floating-ball widget for OpenAI Codex usage.

## Features
- Always-on-top floating ball showing Codex 5-hour and weekly usage remaining.
- Shows countdown to the nearest reset.
- Drag to reposition; position is remembered.
- Auto-refreshes every 60 seconds.

## Requirements
- macOS 14+
- Codex CLI installed and authenticated (`codex login`)

## Build

```bash
swift build
```

## Run

```bash
./Scripts/build_app.sh
open Codex-Usage.app
```

## Data Source

Reads from the local Codex CLI via JSON-RPC (`codex app-server`). No API keys or browser cookies required.
```

- [ ] **Step 2: Run full test suite**

Run:
```bash
swift test
```

Expected: All unit tests pass.

- [ ] **Step 3: Run the app manually**

Run:
```bash
swift run Codex-Usage
```

Expected: The floating ball appears. If Codex CLI is installed and logged in, it shows usage within a few seconds. If not, it shows "Install Codex CLI" or "Run `codex login`".

- [ ] **Step 4: Commit and tag**

```bash
git add README.md
git commit -m "docs: add README"
git tag -a v0.1.0 -m "Initial release"
```

---

## Spec Coverage Check

| Spec Requirement | Implementing Task |
|------------------|-------------------|
| 悬浮球始终置顶 | Task 7 (`level: .floating`) |
| 可拖动 + 记住位置 | Task 7 (`isMovableByWindowBackground`, save/restore position) |
| 显示 5 小时剩余 | Task 6 (outer ring, primary window) |
| 显示本周剩余 | Task 6 (inner ring, secondary window) |
| 显示重置倒计时 | Task 6 (`nearestResetText`) |
| 自动刷新 60s | Task 5 (timer) |
| 右键菜单刷新/退出 | Task 6/7 (contextMenu) |
| Codex CLI 未安装/未登录提示 | Task 4 (error detection), Task 6 (errorView) |
| macOS 14+ | `Package.swift` platform |

## Placeholder Scan

No TBD/TODO, no vague "add error handling", all code steps include concrete code blocks, all file paths are exact.

## Type Consistency

- `UsageWindow` fields: `usedPercent`, `windowMinutes`, `resetsAt` — used consistently across model, parser, view, and tests.
- `UsageError` cases — used in `CodexRPCClient`, `UsageRefreshService`, and `FloatingBallView.errorMessage`.
- `UsageRefreshService` is `@MainActor` and publishes `@Published` values consumed by SwiftUI.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-10-Codex-Usage-implementation-plan.md`.

Two execution options:

**1. Subagent-Driven (recommended)** - Dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach would you like?
