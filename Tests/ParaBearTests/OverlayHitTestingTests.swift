import AppKit
import SwiftUI
import Testing
@testable import ParaBear

/// The overlay panel floats over somebody's desktop, so anywhere it is not drawing has to let the
/// click through to whatever is behind it.
///
/// The window is 500 × 460 because the rig has to be able to hang off a screen edge — see
/// `BearOverlayWindowController.centerTravelBounds` — while the rig itself is 244 across at the
/// canopy and 106 at the bear. All the rest is air.
@MainActor
struct OverlayHitTestingTests {
    /// The complaint this exists for: the padding either side of the rig is nothing but desktop.
    @Test func theEmptyMarginsEitherSideOfTheRigLetClicksThrough() {
        for x in [2.0, 20.0, 60.0, 440.0, 480.0, 498.0] {
            for y in [30.0, 120.0, 240.0, 380.0] {
                #expect(
                    !RigLayout.contains(CGPoint(x: x, y: y)),
                    "click swallowed at (\(x), \(y))"
                )
            }
        }
    }

    @Test func theEmptySpaceAboveAndBelowTheRigLetsClicksThrough() {
        #expect(!RigLayout.contains(CGPoint(x: 250, y: 2)))
        #expect(!RigLayout.contains(CGPoint(x: 250, y: 455)))
    }

    /// The corners either side of the dome are sky, which is why the canopy contributes its outline
    /// and not its bounding box.
    @Test func theSkyEitherSideOfTheDomeLetsClicksThrough() {
        let canopy = RigLayout.canopyRect

        #expect(!RigLayout.contains(CGPoint(x: canopy.minX + 2, y: canopy.minY + 2)))
        #expect(!RigLayout.contains(CGPoint(x: canopy.maxX - 2, y: canopy.minY + 2)))
    }

    /// And the same either side of the bear, which is the narrowest thing on the rig. A box that
    /// held every angle it might be leaning at was 78 points wider on each side than a bear 106
    /// across, and every one of those points sat over the desktop taking clicks.
    @Test func theAirEitherSideOfTheBearLetsClicksThrough() {
        let bear = RigLayout.bearRect

        #expect(!RigLayout.contains(CGPoint(x: bear.minX - 30, y: bear.midY)))
        #expect(!RigLayout.contains(CGPoint(x: bear.maxX + 30, y: bear.midY)))
    }

    /// The lines gather to a knot, so the triangles either side of the fan are air too.
    @Test func theAirEitherSideOfTheRiggingLinesLetsClicksThrough() {
        let lines = RigLayout.linesRect

        #expect(!RigLayout.contains(CGPoint(x: lines.minX + 6, y: lines.maxY - 6)))
        #expect(!RigLayout.contains(CGPoint(x: lines.maxX - 6, y: lines.maxY - 6)))
    }

    /// And the rig is still grabbable, or the drag and the taps would be gone with it.
    @Test func theRigItselfStillTakesClicks() {
        #expect(RigLayout.contains(CGPoint(x: 250, y: RigLayout.canopyRect.midY)))
        #expect(RigLayout.contains(CGPoint(x: 250, y: RigLayout.bearRect.midY)))
    }

    /// A leaning bear is grabbed where it is leaning, not where it hangs at rest. This is the whole
    /// reason the view reports its pose back to the window.
    @Test func aLeaningBearIsGrabbableWhereItActuallyIs() {
        let bear = RigLayout.bearRect
        let degrees = 20.0
        // Its feet, thrown sideways by the lean. The bear turns about the top of its head, so the
        // displacement grows all the way down its height — and to the *left*, which is the
        // direction `BearSwing` calls positive.
        let feet = CGPoint(
            x: bear.midX - (bear.height - 10) * sin(degrees * .pi / 180),
            y: bear.minY + (bear.height - 10) * cos(degrees * .pi / 180)
        )

        #expect(RigLayout.contains(feet, pose: RigPose(bearDegrees: degrees)))
        #expect(!RigLayout.contains(feet, pose: .resting))
    }

    /// The region is hand-written, so it is measured against what is actually drawn: every pixel
    /// the rig paints has to fall inside it, or something would be visible but unclickable.
    @Test func theRegionCoversEveryPixelTheRigPaints() throws {
        let settings = SettingsStore()
        // At rest, so the measurement is repeatable. `BearOverlayView` picks a random wind seed, so
        // a moving rig lands somewhere different every run.
        settings.animationIntensity = 0
        let view = BearOverlayView(
            viewModel: EventTimelineViewModel(
                calendarService: CalendarService(),
                settings: settings
            ),
            settings: settings,
            driftState: BearDriftState()
        )

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1

        let image = try #require(renderer.cgImage)
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        let context = try #require(
            CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var uncovered = 0
        var firstMiss: CGPoint?

        for row in 0..<height {
            for column in 0..<width {
                // The rig paints a soft drop shadow that spreads well past the fabric. A shadow is
                // not a thing anyone aims at, so only what is solidly drawn has to be covered.
                guard pixels[(row * width + column) * 4 + 3] > 160 else { continue }

                let point = CGPoint(x: Double(column) + 0.5, y: Double(row) + 0.5)
                if !RigLayout.contains(point) {
                    uncovered += 1
                    if firstMiss == nil { firstMiss = point }
                }
            }
        }

        #expect(
            uncovered == 0,
            "\(uncovered) drawn pixels outside the region, first at \(firstMiss as Any)"
        )
    }

    /// And it is genuinely a small part of the window, or none of the above proves anything.
    @Test func theRegionIsAFractionOfTheWindow() {
        let bounds = RigLayout.bounds()
        let window = RigLayout.windowSize

        #expect(bounds.width < window.width * 0.62)
        #expect(bounds.height < window.height * 0.95)
    }
}

/// `hitTest` chooses which view inside a window takes an event the window server has *already*
/// given to that window. Making the click reach the application underneath needs
/// `ignoresMouseEvents`, which the drift loop steers from the pointer's screen position — so the
/// screen-to-rig conversion is the thing that has to be right.
@MainActor
struct ClickThroughTests {
    /// A window somewhere off-origin, so an error in the conversion cannot cancel itself out.
    private let frame = NSRect(x: 300, y: 200, width: 500, height: 460)

    /// Screen coordinates run up from the bottom; the layout is stated down from the top.
    private func screenPoint(rigX: CGFloat, rigY: CGFloat) -> CGPoint {
        CGPoint(x: frame.minX + rigX, y: frame.maxY - rigY)
    }

    @Test func theRigItselfKeepsItsClicks() {
        for rigY in [RigLayout.canopyRect.midY, RigLayout.bearRect.midY] {
            #expect(
                !BearOverlayWindowController.passesThrough(
                    pointer: screenPoint(rigX: 250, rigY: rigY),
                    windowFrame: frame
                )
            )
        }
    }

    @Test func theEmptyAirAroundItDoesNot() {
        let air = [
            screenPoint(rigX: 20, rigY: 240), screenPoint(rigX: 480, rigY: 240),
            screenPoint(rigX: 250, rigY: 2), screenPoint(rigX: 250, rigY: 456)
        ]

        for point in air {
            #expect(
                BearOverlayWindowController.passesThrough(pointer: point, windowFrame: frame)
            )
        }
    }

    /// The conversion flips y. Reflecting a point about the window's middle must not give the same
    /// answer, or an upside-down conversion would pass every test above.
    @Test func theConversionIsNotSymmetricAboutTheMiddle() {
        let nearTheCanopy = screenPoint(rigX: 250, rigY: 40)
        let mirrored = screenPoint(rigX: 250, rigY: RigLayout.windowSize.height - 40)

        #expect(
            BearOverlayWindowController.passesThrough(pointer: nearTheCanopy, windowFrame: frame)
                != BearOverlayWindowController.passesThrough(pointer: mirrored, windowFrame: frame)
        )
    }
}
