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

    private func temporaryDirectory() throws -> String {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.path
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

    func testResolveCodexExecutableIgnoresNonexistentOverride() throws {
        setCodexCLIPathOverride("/nonexistent/path/to/codex")

        let executor = DefaultCodexCLIExecutor()

        // When the override does not exist, the executor should fall through to
        // common install locations and `which`. The exact result depends on the
        // test environment, so we only assert that the invalid override is not
        // returned.
        let resolved = executor.resolveCodexExecutable()
        XCTAssertNotEqual(resolved, "/nonexistent/path/to/codex")
    }

    func testResolveCodexExecutableRejectsRelativeOverride() throws {
        let path = try temporaryExecutable()
        // Use a relative path to the same valid file.
        let relative = (path as NSString).lastPathComponent
        setCodexCLIPathOverride(relative)

        let executor = DefaultCodexCLIExecutor()

        let resolved = executor.resolveCodexExecutable()
        XCTAssertNotEqual(resolved, path)
        XCTAssertNotEqual(resolved, relative)
    }

    func testResolveCodexExecutableRejectsOverrideWithWrongName() throws {
        let directory = try temporaryDirectory()
        let path = (directory as NSString).appendingPathComponent("not-codex")
        FileManager.default.createFile(atPath: path, contents: Data("#!/bin/sh\n".utf8))
        setCodexCLIPathOverride(path)

        let executor = DefaultCodexCLIExecutor()

        XCTAssertNotEqual(executor.resolveCodexExecutable(), path)
    }

    func testResolveCodexExecutableRejectsDirectoryOverride() throws {
        let directory = try temporaryDirectory()
        setCodexCLIPathOverride(directory)

        let executor = DefaultCodexCLIExecutor()

        XCTAssertNotEqual(executor.resolveCodexExecutable(), directory)
    }

    func testResolveCodexExecutableRejectsOverrideWithControlCharacters() throws {
        let path = try temporaryExecutable()
        let directory = (path as NSString).deletingLastPathComponent
        let malicious = (directory as NSString).appendingPathComponent("co\ndex")
        setCodexCLIPathOverride(malicious)

        let executor = DefaultCodexCLIExecutor()

        // The malicious override must not be used. A real codex installation on
        // the current machine may still be discovered, so we only assert that
        // the resolved path is not the malicious one.
        XCTAssertNotEqual(executor.resolveCodexExecutable(), malicious)
    }

    func testResolveCodexExecutableTrimsLeadingAndTrailingWhitespace() throws {
        let path = try temporaryExecutable()
        setCodexCLIPathOverride("  \(path)  ")

        let executor = DefaultCodexCLIExecutor()

        XCTAssertEqual(executor.resolveCodexExecutable(), path)
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

        if executor.resolveCodexExecutable() == nil {
            // No codex installation was found; the executor should fall back to
            // invoking `codex` through /usr/bin/env.
            XCTAssertEqual(process.executableURL?.path, "/usr/bin/env")
            XCTAssertEqual(process.arguments, ["codex", "-s", "read-only", "-a", "untrusted", "app-server"])
        } else {
            // A real codex installation is present on this machine, so the
            // resolved executable should be used directly.
            XCTAssertNotEqual(process.executableURL?.path, "/usr/bin/env")
            XCTAssertEqual(process.arguments, ["-s", "read-only", "-a", "untrusted", "app-server"])
        }
    }
}
