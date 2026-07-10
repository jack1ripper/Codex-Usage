import Foundation
import Combine

@MainActor
final class UsageRefreshService: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var error: UsageError?
    @Published private(set) var isLoading: Bool = false
    
    private let rpcClient: CodexRPCClientProtocol
    private var timer: Timer?
    private let refreshInterval: TimeInterval
    
    init(rpcClient: CodexRPCClientProtocol = CodexRPCClient(), refreshInterval: TimeInterval = 60) {
        self.rpcClient = rpcClient
        self.refreshInterval = refreshInterval
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
}

#if DEBUG
extension UsageRefreshService {
    convenience init(previewSnapshot snapshot: UsageSnapshot) {
        self.init()
        self.snapshot = snapshot
    }
}
#endif
