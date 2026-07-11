import SwiftUI

enum FloatingPanelSize: String, CaseIterable, Identifiable {
    case standard = "standard"
    case small = "small"

    var id: String { rawValue }

    var cardSize: CGSize {
        switch self {
        case .standard:
            return CGSize(width: 220, height: 84)
        case .small:
            return CGSize(width: 200, height: 84)
        }
    }

    var localizedName: String {
        switch self {
        case .standard: return "标准"
        case .small: return "紧凑"
        }
    }

}

enum UsageColorPolicy {
    static func color(for kind: UsageQuotaKind, remainingRatio: Double) -> Color {
        let displayedPercent = Int((min(1, max(0, remainingRatio)) * 100).rounded())

        switch displayedPercent {
        case ..<10:
            return .usageCritical
        case 10..<30:
            return .usageWarning
        default:
            switch kind {
            case .primary: return .usageBlue
            case .weekly: return .usageWeekly
            }
        }
    }

}

enum UsageProgressLayout {
    static func fillWidth(totalWidth: CGFloat, ratio: Double) -> CGFloat {
        totalWidth * CGFloat(min(1, max(0, ratio)))
    }
}

enum FloatingPanelAppearance {
    static let cornerRadius: CGFloat = 18
    static let shadowOpacity = 0.12
    static let shadowRadius: CGFloat = 10
    static let shadowOffset = CGSize(width: 0, height: 4)
    static let shadowSafetyMargin: CGFloat = 4

    static var minimumShadowInset: CGFloat {
        shadowRadius
            + max(abs(shadowOffset.width), abs(shadowOffset.height))
            + shadowSafetyMargin
    }
}

enum FloatingPanelLayout {
    static let shadowInset = FloatingPanelAppearance.minimumShadowInset

    static func windowSize(for cardSize: CGSize) -> CGSize {
        CGSize(
            width: cardSize.width + shadowInset * 2,
            height: cardSize.height + shadowInset * 2
        )
    }

    static func resizedFrameKeepingTopEdge(
        _ frame: CGRect,
        newSize: CGSize
    ) -> CGRect {
        CGRect(
            x: frame.minX,
            y: frame.maxY - newSize.height,
            width: newSize.width,
            height: newSize.height
        )
    }

    static func visibleFrame(
        containing origin: CGPoint,
        candidates: [CGRect]
    ) -> CGRect? {
        candidates.first(where: { $0.contains(origin) })
    }
}

enum FloatingPanelPreference {
    static let visibilityKey = "showFloatingUsagePanel"

    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: visibilityKey) != nil else {
            return true
        }
        return defaults.bool(forKey: visibilityKey)
    }
}

extension Color {
    static let usageBlue = Color(red: 0.29, green: 0.56, blue: 0.99)
    static let usageWeekly = Color(red: 0.55, green: 0.36, blue: 0.96)
    static let usageWarning = Color(red: 0.96, green: 0.59, blue: 0.15)
    static let usageCritical = Color(red: 0.95, green: 0.28, blue: 0.28)
}
