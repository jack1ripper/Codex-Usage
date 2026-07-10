import SwiftUI
import Combine

struct FloatingBallView: View {
    @ObservedObject var service: UsageRefreshService
    let onRefresh: () -> Void
    let onQuit: () -> Void

    @State private var now = Date()
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

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
                } else if snapshot != nil {
                    usageView
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .frame(width: 120, height: 120)
        }
        .frame(width: 140, height: 140)
        .contextMenu {
            Button("Refresh") { onRefresh() }
            Divider()
            Button("Quit") { onQuit() }
        }
        .onReceive(timer) { _ in
            now = Date()
        }
    }

    private var usageView: some View {
        ZStack {
            ring(ratio: primaryWindow?.remainingRatio ?? 0, lineWidth: 10, radius: 58)
            ring(ratio: secondaryWindow?.remainingRatio ?? 0, lineWidth: 8, radius: 44)

            VStack(spacing: 2) {
                Text(countdownText)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("until reset")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    percentLabel(title: "5h", window: primaryWindow)
                    percentLabel(title: "Wk", window: secondaryWindow)
                }
                .padding(.top, 2)
            }
        }
    }

    private func ring(ratio: Double, lineWidth: CGFloat, radius: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: lineWidth)
                .frame(width: radius * 2, height: radius * 2)

            Circle()
                .trim(from: 0, to: ratio)
                .stroke(progressColor(for: ratio), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: radius * 2, height: radius * 2)
                .rotationEffect(.degrees(-90))
        }
    }

    private func progressColor(for ratio: Double) -> Color {
        switch ratio {
        case ..<0.1:
            return .red
        case 0.1..<0.3:
            return .yellow
        default:
            return .cyan
        }
    }

    private var countdownText: String {
        let candidates = [primaryWindow?.resetsAt, secondaryWindow?.resetsAt].compactMap { $0 }
        guard let nearest = candidates.filter({ $0 > now }).min() else {
            return "—"
        }

        let totalSeconds = nearest.timeIntervalSince(now)
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func percentLabel(title: String, window: UsageWindow?) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))

            Text(window.map { "\(Int($0.remainingPercent))%" } ?? "—")
                .font(.system(size: 10))
                .foregroundColor(.white)
        }
    }

    private func errorView(_ error: UsageError) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundColor(.yellow)

            Text(errorMessage(for: error))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.horizontal, 8)
    }

    private func errorMessage(for error: UsageError) -> String {
        switch error {
        case .cliNotFound:
            return "Install Codex CLI"
        case .notAuthenticated:
            return "Run `codex login`"
        case .rpcFailed(let msg), .decodeFailed(let msg):
            let maxLength = 40
            if msg.count > maxLength {
                return String(msg.prefix(maxLength)) + "…"
            }
            return msg
        }
    }
}

#Preview {
    FloatingBallView(
        service: UsageRefreshService(previewSnapshot: UsageSnapshot(
            primary: UsageWindow(
                usedPercent: 30,
                windowMinutes: 300,
                resetsAt: Date().addingTimeInterval(3600)
            ),
            secondary: UsageWindow(
                usedPercent: 60,
                windowMinutes: 10080,
                resetsAt: Date().addingTimeInterval(86400)
            ),
            fetchedAt: Date()
        )),
        onRefresh: {},
        onQuit: {}
    )
}
