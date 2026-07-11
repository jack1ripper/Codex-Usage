# Floating Panel Natural Shadow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the clipped manual shadow layer with a subtle shape-native shadow that follows the floating panel's 18 pt continuous rounded rectangle.

**Architecture:** `FloatingPanelAppearance` owns the card and shadow metrics as pure values, while `FloatingPanelLayout` derives a symmetric transparent-window inset large enough for the complete blur and offset. `FloatingBallView` applies the shadow only to the rounded material background, leaving content and interaction behavior unchanged.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Swift Package Manager, XCTest.

## Global Constraints

- Target macOS 14 or later with no new third-party dependencies.
- Keep standard and compact card sizes at 220×84 pt and 200×84 pt.
- Keep the material, border, quota content, context menu, dragging, and saved position behavior unchanged.
- Use an 18 pt continuous corner radius for material, highlight, border, and shadow silhouette.
- Preserve all unrelated changes in the dirty working tree.
- Do not create an implementation commit unless the user requests one.

---

### Task 1: Make Shadow Geometry Explicit and Prevent Window Clipping

**Files:**
- Modify: `Tests/Codex-UsageTests/BallStyleTests.swift`
- Modify: `Sources/Codex-Usage/Models/BallStyle.swift`

**Interfaces:**
- Produces: `FloatingPanelAppearance.cornerRadius: CGFloat`
- Produces: `FloatingPanelAppearance.shadowOpacity: Double`
- Produces: `FloatingPanelAppearance.shadowRadius: CGFloat`
- Produces: `FloatingPanelAppearance.shadowOffset: CGSize`
- Produces: `FloatingPanelAppearance.shadowSafetyMargin: CGFloat`
- Produces: `FloatingPanelAppearance.minimumShadowInset: CGFloat`
- Updates: `FloatingPanelLayout.shadowInset: CGFloat`

- [x] **Step 1: Write the failing shadow-geometry test**

Add this test to `BallStyleTests` and update the existing window-size expectation from `244×108` to `256×120`:

```swift
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
```

- [x] **Step 2: Run the focused test and verify RED**

Run:

```bash
swift test --filter BallStyleTests
```

Expected: test compilation fails because `FloatingPanelAppearance` does not exist yet. This proves the test exercises the new public style contract.

- [x] **Step 3: Add the minimal appearance values and derived safe inset**

Add this before `FloatingPanelLayout` in `BallStyle.swift`:

```swift
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
```

Change the layout constant to:

```swift
static let shadowInset = FloatingPanelAppearance.minimumShadowInset
```

- [x] **Step 4: Run the focused test and verify GREEN**

Run:

```bash
swift test --filter BallStyleTests
```

Expected: all `BallStyleTests` pass, including a 256×120 pt standard host window and the 18 pt minimum inset.

---

### Task 2: Attach the Shadow to the Card Silhouette

**Files:**
- Modify: `Sources/Codex-Usage/Views/FloatingBallView.swift`

**Interfaces:**
- Consumes: all `FloatingPanelAppearance` metrics from Task 1.
- Preserves: `FloatingBallView` initializer and all callbacks.

- [x] **Step 1: Remove the manual blurred shadow copy**

Replace the outer `ZStack` and its filled/offset/blurred `RoundedRectangle` with the existing `HStack` as the card root. Keep its fixed `cardSize` frame.

- [x] **Step 2: Apply one shape-native shadow to the rounded material**

Use the same shape and metrics for the material, white highlight, border, and shadow:

```swift
.background(
    RoundedRectangle(
        cornerRadius: FloatingPanelAppearance.cornerRadius,
        style: .continuous
    )
    .fill(.regularMaterial)
    .shadow(
        color: Color.black.opacity(FloatingPanelAppearance.shadowOpacity),
        radius: FloatingPanelAppearance.shadowRadius,
        x: FloatingPanelAppearance.shadowOffset.width,
        y: FloatingPanelAppearance.shadowOffset.height
    )
    .overlay(
        RoundedRectangle(
            cornerRadius: FloatingPanelAppearance.cornerRadius,
            style: .continuous
        )
        .fill(Color.white.opacity(0.54))
    )
    .overlay(
        RoundedRectangle(
            cornerRadius: FloatingPanelAppearance.cornerRadius,
            style: .continuous
        )
        .stroke(Color.black.opacity(0.10), lineWidth: 0.8)
    )
)
```

Keep `.padding(FloatingPanelLayout.shadowInset)` so the transparent host window includes the full shadow.

- [x] **Step 3: Build and run all tests**

Run:

```bash
swift build
swift test
```

Expected: both commands exit 0 with no test failures.

---

### Task 3: Package, Reinstall, and Visually Verify

**Files:**
- Verify: `Codex-Usage.app`
- Verify: `/Applications/Codex-Usage.app`

**Interfaces:**
- Consumes: the completed SwiftUI shadow and layout metrics.
- Produces: a freshly installed and launched app for visual inspection.

- [x] **Step 1: Build the app bundle**

Run:

```bash
./Scripts/build_app.sh
```

Expected: exit 0 and a rebuilt `Codex-Usage.app` in the project root.

- [x] **Step 2: Remove the old installed copy and reinstall**

Run:

```bash
osascript -e 'quit app "Codex-Usage"'
rm -rf /Applications/Codex-Usage.app
./Scripts/install.sh
open /Applications/Codex-Usage.app
```

Expected: the new application launches and shows the desktop floating panel.

- [x] **Step 3: Capture and inspect the live panel**

Capture the installed panel at native resolution. Verify that the shadow starts from the same 18 pt rounded silhouette, fades continuously on all four corners, is slightly stronger below the card, and never meets a straight transparent-window edge.

- [x] **Step 4: Review the final working-tree diff**

Run:

```bash
git diff --check
git status --short
git diff -- Sources/Codex-Usage/Models/BallStyle.swift Sources/Codex-Usage/Views/FloatingBallView.swift Tests/Codex-UsageTests/BallStyleTests.swift
```

Expected: no whitespace errors, only the approved shadow implementation and its regression test in these files, while unrelated user changes remain untouched.
