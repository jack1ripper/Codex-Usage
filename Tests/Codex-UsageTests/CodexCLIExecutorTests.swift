import XCTest
@testable import Codex_Usage

final class CodexCLIExecutorTests: XCTestCase {
    private func setCodexCLIPathOverride(_ path: String?) {
        if let path {
            UserDefaults.standard.set(path, forKey: "codexCLIPath")
        } else {
            UserDefaults.standard.removeObject(forKey: "codexCLIPath")
        }
    }

    private func temporaryExecutable() throws -> String {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent("codex").path
        FileManager.default.createFile(atPath: path, contents: Data("#!/bin/sh\n".utf8))
        return path
    }

    override func setUp() {
        super.setUp()
        setCodexCLIPathOverride(nil)
    }

    override func tearDown() {
        setCodexCLIPathOverride(nil)
        super.tearDown()
    }

    func testResolveCodexExecutableReturnsUserDefaultsOverride() throws {
        let path = try temporaryExecutable()
        setCodexCLIPathOverride(path)

        let executor = DefaultCodexCLIExecutor()

        XCTAssertEqual(executor.resolveCodexExecutable(), path)
        XCTAssertTrue(executor.isInstalled)
    }

    func testResolveCodexExecutableIgnoresInvalidUserDefaultsOverride() throws {
        setCodexCLIPathOverride("/nonexistent/path/to/codex")

        let executor = DefaultCodexCLIExecutor()

        // When the override does not exist, the executor should fall through to
        // common install locations and `which`. The exact result depends on the
        // test environment, so we only assert that the invalid override is not
        // returned.
        let resolved = executor.resolveCodexExecutable()
        XCTAssertNotEqual(resolved, "/nonexistent/path/to/codex")
    }

    func testExecuteUsesResolvedExecutablePath() throws {
        let path = try temporaryExecutable()
        setCodexCLIPathOverride(path)

        let executor = DefaultCodexCLIExecutor()
        let process = try executor.execute()

        XCTAssertEqual(process.executableURL?.path, path)
        XCTAssertEqual(process.arguments, ["-s", "read-only", "-a", "untrusted", "app-server"])
    }

    func testExecuteFallsBackToEnvWhenNotResolved() throws {
        setCodexCLIPathOverride(nil)
        let executor = DefaultCodexCLIExecutor()

        let process = try executor.execute()

        XCTAssertEqual(process.executableURL?.path, "/usr/bin/env")
        XCTAssertEqual(process.arguments, ["codex", "-s", "read-only", "-a", "untrusted", "app-server"])
    }
}
