# Floating Panel Natural Shadow Design

## Goal

Make the desktop floating panel's shadow follow the same continuous rounded
rectangle as the visible card. The shadow must fade naturally into the desktop
without exposing the rectangular boundary of the transparent host window.

## Root Cause

The current SwiftUI view draws a second, solid black rounded rectangle, offsets
it by 6 pt, and blurs it by 12 pt. `FloatingPanelLayout` reserves only 12 pt on
each side of the card, so the bottom of that blur needs more room than the
transparent `NSPanel` provides. The window clips the blur and reveals a straight
rectangular edge.

## Chosen Design

- Keep the existing 220×84 pt and 200×84 pt card sizes.
- Keep one shared 18 pt continuous corner radius for the material, highlight,
  border, and shadow silhouette.
- Remove the manually filled and blurred shadow rectangle.
- Apply one subtle SwiftUI shadow directly to the card background shape, with a
  small downward offset so it reads as lifted from the desktop rather than as a
  uniform glow.
- Reserve enough transparent window inset for the shadow radius and offset so
  no visible shadow reaches a window edge.
- Centralize the corner radius, shadow radius, offset, opacity, and safe inset
  in a pure layout/style value that can be covered by unit tests.
- Preserve the panel's content, context menu, drag behavior, saved position,
  material, border, and quota layout.

## Alternatives Considered

1. **SwiftUI shape-native shadow (chosen):** Smallest change and keeps the
   shadow tied to the exact SwiftUI card silhouette.
2. **`CALayer.shadowPath`:** Provides an explicit AppKit path, but requires
   keeping an AppKit layer frame and corner path synchronized with the SwiftUI
   card and its size preference.
3. **Native `NSPanel` shadow:** Has the least code but can use the borderless
   transparent window's rectangular bounds and offers insufficient control over
   the desired silhouette.

## Verification

- Add a failing layout test proving the window inset exceeds the shadow's blur
  radius plus its downward offset.
- Run the focused layout tests, then `swift build`, `swift test`, and
  `./Scripts/build_app.sh`.
- Quit the installed copy, reinstall, and relaunch it.
- Capture the live floating panel and verify that all four corners fade from the
  rounded card silhouette and that no straight clipping edge is visible.

## Acceptance Criteria

- The shadow follows the panel's 18 pt continuous rounded corners.
- No rectangular halo or hard clipping line is visible around the transparent
  window.
- The shadow remains subtle and slightly stronger below the panel.
- The card dimensions and all interaction behavior remain unchanged.
