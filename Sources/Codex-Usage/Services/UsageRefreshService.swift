import Foundation
import Combine

@MainActor
final class UsageRefreshService: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var error: UsageError?
    @Published private(set) var isLoading: Bool = false
    
    private let rpcClient: CodexRPCClientProtocol
    private let userDefaults: UserDefaults
    private var timer: Timer?
    private var refreshInterval: TimeInterval
    
    init(rpcClient: CodexRPCClientProtocol = CodexRPCClient(), userDefaults: UserDefaults = .standard) {
        self.rpcClient = rpcClient
        self.userDefaults = userDefaults
        self.refreshInterval = Self.readRefreshInterval(from: userDefaults)
        observeRefreshIntervalChanges()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func start() {
        guard timer == nil else { return }
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
        } catch let usageError as UsageError {
            error = usageError
        } catch {
            self.error = .rpcFailed(error.localizedDescription)
        }
        isLoading = false
    }

    // MARK: - Refresh interval

    /// The current refresh interval in seconds.
    internal var currentRefreshInterval: TimeInterval { refreshInterval }

    /// Whether the refresh timer is currently active.
    internal var isTimerActive: Bool { timer != nil }

    private static func readRefreshInterval(from userDefaults: UserDefaults) -> TimeInterval {
        guard userDefaults.object(forKey: "refreshInterval") != nil else { return 60 }
        let value = userDefaults.double(forKey: "refreshInterval")
        return min(300, max(10, value))
    }

    private func observeRefreshIntervalChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshIntervalDidChange),
            name: UserDefaults.didChangeNotification,
            object: userDefaults
        )
    }

    @objc private func refreshIntervalDidChange() {
        applyRefreshIntervalFromUserDefaults()
    }

    /// Reads the current refresh interval from `UserDefaults` and recreates the
    /// timer if the service is already running and the interval changed.
    func applyRefreshIntervalFromUserDefaults() {
        let newInterval = Self.readRefreshInterval(from: userDefaults)
        guard newInterval != refreshInterval else { return }

        refreshInterval = newInterval
        if timer != nil {
            stop()
            start()
        }
    }
}

#if DEBUG
extension UsageRefreshService {
    convenience init(previewSnapshot snapshot: UsageSnapshot) {
        self.init()
        self.snapshot = snapshot
    }
}
#endif
