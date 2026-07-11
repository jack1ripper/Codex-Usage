import XCTest
@testable import Codex_Usage

final class BallStyleTests: XCTestCase {
    func testFloatingPanelSizeMapping() {
        XCTAssertEqual(FloatingPanelSize.standard.cardSize, CGSize(width: 220, height: 84))
        XCTAssertEqual(FloatingPanelSize.small.cardSize, CGSize(width: 200, height: 84))
    }

    func testFloatingPanelSizeLocalizedNames() {
        XCTAssertEqual(FloatingPanelSize.standard.localizedName, "标准")
        XCTAssertEqual(FloatingPanelSize.small.localizedName, "紧凑")
    }

    func testColorPolicyThresholds() {
        XCTAssertEqual(UsageColorPolicy.color(for: .primary, remainingRatio: 1.0), .usageBlue)
        XCTAssertEqual(UsageColorPolicy.color(for: .weekly, remainingRatio: 1.0), .usageWeekly)
        XCTAssertEqual(UsageColorPolicy.color(for: .primary, remainingRatio: 0.30), .usageBlue)
        XCTAssertEqual(UsageColorPolicy.color(for: .weekly, remainingRatio: 0.29), .usageWarning)
        XCTAssertEqual(UsageColorPolicy.color(for: .primary, remainingRatio: 0.10), .usageWarning)
        XCTAssertEqual(UsageColorPolicy.color(for: .weekly, remainingRatio: 0.09), .usageCritical)
        XCTAssertEqual(UsageColorPolicy.color(for: .primary, remainingRatio: 0.0), .usageCritical)
        XCTAssertEqual(UsageColorPolicy.color(for: .primary, remainingRatio: 0.095), .usageWarning)
        XCTAssertEqual(UsageColorPolicy.color(for: .weekly, remainingRatio: 0.295), .usageWeekly)
    }

    func testProgressFillWidthClampsRatio() {
        XCTAssertEqual(UsageProgressLayout.fillWidth(totalWidth: 100, ratio: -0.5), 0)
        XCTAssertEqual(UsageProgressLayout.fillWidth(totalWidth: 100, ratio: 0.42), 42)
        XCTAssertEqual(UsageProgressLayout.fillWidth(totalWidth: 100, ratio: 1.5), 100)
    }

    func testFloatingPanelLayoutAddsShadowInsetsAndKeepsTopEdge() {
        XCTAssertEqual(
            FloatingPanelLayout.windowSize(for: CGSize(width: 220, height: 84)),
            CGSize(width: 256, height: 120)
        )

        let original = CGRect(x: 100, y: 200, width: 256, height: 120)
        let resized = FloatingPanelLayout.resizedFrameKeepingTopEdge(
            original,
            newSize: CGSize(width: 236, height: 120)
        )

        XCTAssertEqual(resized.minX, 100)
        XCTAssertEqual(resized.maxY, original.maxY)
        XCTAssertEqual(resized.size, CGSize(width: 236, height: 120))
    }

    func testFloatingPanelShadowMetricsReserveSafeDrawingArea() {
        XCTAssertEqual(FloatingPanelAppearance.cornerRadius, 18)
        XCTAssertEqual(FloatingPanelAppearance.shadowRadius, 10)
        XCTAssertEqual(FloatingPanelAppearance.shadowOffset, CGSize(width: 0, height: 4))
        XCTAssertEqual(FloatingPanelAppearance.minimumShadowInset, 18)
        XCTAssertGreaterThanOrEqual(
            FloatingPanelLayout.shadowInset,
            FloatingPanelAppearance.minimumShadowInset
        )
    }

    func testFloatingPanelLayoutChoosesTheScreenContainingSavedOrigin() throws {
        let primary = CGRect(x: 0, y: 0, width: 1_728, height: 1_117)
        let secondary = CGRect(x: 1_728, y: 0, width: 1_920, height: 1_080)

        XCTAssertEqual(
            FloatingPanelLayout.visibleFrame(
                containing: CGPoint(x: 1_730, y: 200),
                candidates: [primary, secondary]
            ),
            secondary
        )
        XCTAssertNil(FloatingPanelLayout.visibleFrame(
            containing: CGPoint(x: -500, y: -500),
            candidates: [primary, secondary]
        ))
    }

    func testFloatingPanelVisibilityDefaultsToEnabled() throws {
        let suiteName = "BallStyleTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertTrue(FloatingPanelPreference.isEnabled(in: defaults))

        defaults.set(false, forKey: FloatingPanelPreference.visibilityKey)
        XCTAssertFalse(FloatingPanelPreference.isEnabled(in: defaults))

        defaults.set(true, forKey: FloatingPanelPreference.visibilityKey)
        XCTAssertTrue(FloatingPanelPreference.isEnabled(in: defaults))
    }
}
