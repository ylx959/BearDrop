import CoreGraphics
import SwiftUI
import Testing
@testable import ParaBear

/// The tap target is invisible, so what makes it usable is that it is the *obvious* region — and on
/// a drawing of a bear the obvious region is the bear.
///
/// This inverts the check that used to live here. While the target was an ellipse over the belly,
/// the thing worth guarding was that no part of it hung off the silhouette onto somebody's desktop.
/// Now that it is the whole figure, the failure worth guarding is the opposite one: a piece of bear
/// you can see but cannot click.
struct BearTapTargetTests {
    @MainActor
    @Test func everyPartOfTheBearIsTappable() throws {
        let view = BearCharacterView(mood: .calm, appearance: .dark)
            .frame(
                width: BearCharacterView.sourceRect.width,
                height: BearCharacterView.sourceRect.height
            )

        let drawn = try SolidPixels(of: view)
        let region = BearTapTarget.region(
            in: CGSize(width: drawn.width, height: drawn.height)
        )

        var untappable = 0
        var firstMiss: CGPoint?
        var bearPixels = 0

        drawn.forEachPixel { column, row in
            guard drawn.isSolid(column: column, row: row) else { return }

            bearPixels += 1
            let point = drawn.centre(column: column, row: row)
            if !region.contains(point) {
                untappable += 1
                if firstMiss == nil { firstMiss = point }
            }
        }

        #expect(
            untappable == 0,
            "\(untappable) of \(bearPixels) bear pixels cannot be clicked, first at \(firstMiss as Any)"
        )
        // And there is in fact a bear in the picture, or the above passes on an empty render.
        #expect(bearPixels > 0)
    }

    /// It must not reach past the bear either. The window hands the bear's box to the rig rather
    /// than to the desktop, and a target larger than that box would be claiming clicks the window
    /// has already let through.
    @MainActor
    @Test func theTargetStaysWithinTheBearsOwnBox() {
        let size = CGSize(width: 106, height: 203)
        let region = BearTapTarget.region(in: size)

        #expect(region.minX >= 0)
        #expect(region.minY >= 0)
        #expect(region.maxX <= size.width)
        #expect(region.maxY <= size.height)
    }

    /// The bear is drawn centred in its box, so its target is too — whatever the box's size.
    @Test func theTargetIsCentredOnTheBearAtEverySize() {
        for size in [CGSize(width: 106, height: 203), CGSize(width: 184, height: 353)] {
            let region = BearTapTarget.region(in: size)

            #expect(abs(region.midX - size.width / 2) < 0.001)
        }
    }
}
