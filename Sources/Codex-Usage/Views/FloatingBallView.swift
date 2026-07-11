import SwiftUI

/// The optional always-on-top desktop summary. The historical type name is
/// retained so existing controller wiring and previews keep their source ABI.
struct FloatingBallView: View {
    @ObservedObject var service: UsageRefreshService
    let onRefresh: () -> Void
    let onSettings: () -> Void
    let onHide: () -> Void
    let onQuit: () -> Void

    @AppStorage("floatingBallSize") private var panelSizeRaw = FloatingPanelSize.standard.rawValue

    private var panelSize: FloatingPanelSize {
        FloatingPanelSize(rawValue: panelSizeRaw) ?? .standard
    }

    private var cardSize: CGSize { panelSize.cardSize }

    private var state: UsageDisplayState {
        UsageDisplayState.resolve(snapshot: service.snapshot, error: service.error)
    }

    var body: some View {
        ZStack {
            // Shadow layer: same shape as the card so the corners align exactly.
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.14))
                .frame(width: cardSize.width, height: cardSize.height)
                .offset(x: 0, y: 6)
                .blur(radius: 12)

            HStack(spacing: 0) {
                logoRail

                Divider()
                    .padding(.vertical, 9)

                content
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
            }
            .frame(width: cardSize.width, height: cardSize.height)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.54))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.black.opacity(0.10), lineWidth: 0.8)
                    )
            )
        }
        .padding(FloatingPanelLayout.shadowInset)
        .background(Color.clear)
        .preferredColorScheme(.light)
        .contextMenu {
            Button("刷新数据") { onRefresh() }
            Button("打开设置") { onSettings() }
            Button("隐藏悬浮窗") { onHide() }
            Divider()
            Button("退出应用") { onQuit() }
        }
    }

    private var logoRail: some View {
        ZStack(alignment: .topTrailing) {
            CodexUsageLogoView(pointSize: panelSize == .standard ? 21 : 19)

            if case .data(_, let isStale) = state, isStale {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
                    .offset(x: 3, y: -3)
                    .accessibilityLabel("数据可能已过期")
            }
        }
        .frame(width: 28)
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("正在获取用量…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .error(let error):
            HStack(spacing: 8) {
                Image(systemName: errorIcon(for: error))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(errorTitle(for: error))
                        .font(.system(size: 12, weight: .semibold))
                    Text("点击菜单栏图标查看详情")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

        case .data(let snapshot, _):
            VStack(spacing: 0) {
                UsageQuotaRow(
                    presentation: UsageQuotaPresentation(
                        kind: .primary,
                        window: snapshot.primary
                    ),
                    window: snapshot.primary,
                    style: .compact
                )

                Divider()

                UsageQuotaRow(
                    presentation: UsageQuotaPresentation(
                        kind: .weekly,
                        window: snapshot.secondary
                    ),
                    window: snapshot.secondary,
                    style: .compact
                )
            }
        }
    }

    private func errorIcon(for error: UsageError) -> String {
        switch error {
        case .cliNotFound:
            return "terminal"
        case .notAuthenticated:
            return "person.crop.circle.badge.xmark"
        case .rpcFailed, .decodeFailed:
            return "exclamationmark.triangle"
        }
    }

    private func errorTitle(for error: UsageError) -> String {
        switch error {
        case .cliNotFound:
            return "未找到 Codex CLI"
        case .notAuthenticated:
            return "Codex CLI 尚未登录"
        case .rpcFailed, .decodeFailed:
            return "暂时无法获取用量"
        }
    }
}

#if DEBUG
#Preview("Floating panel") {
    FloatingBallView(
        service: UsageRefreshService(previewSnapshot: UsageSnapshot(
            primary: UsageWindow(
                usedPercent: 3,
                windowMinutes: 300,
                resetsAt: Date().addingTimeInterval(4 * 3600)
            ),
            secondary: UsageWindow(
                usedPercent: 1,
                windowMinutes: 10_080,
                resetsAt: Date().addingTimeInterval(7 * 24 * 3600)
            ),
            fetchedAt: Date()
        )),
        onRefresh: {},
        onSettings: {},
        onHide: {},
        onQuit: {}
    )
}
#endif
