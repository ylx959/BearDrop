import AppKit
import Testing
@testable import ParaBear

struct BearOverlayWindowControllerTests {
    @MainActor
    @Test func flightTravelSpreadsSidewaysButStaysOnScreen() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1_440, height: 900)
        let windowWidth: CGFloat = 340
        let centerX = BearOverlayWindowController.centeredOriginX(
            visibleFrame: visibleFrame,
            windowWidth: windowWidth
        )
        let bounds = BearOverlayWindowController.centerTravelBounds(
            visibleFrame: visibleFrame,
            windowWidth: windowWidth
        )
        let allowedTravel = visibleFrame.width * BearOverlayWindowController.maxTravelFromCenterRatio

        #expect(bounds.lowerBound >= centerX - allowedTravel)
        #expect(bounds.upperBound <= centerX + allowedTravel)
        #expect(bounds.contains(centerX))

        // The window is allowed to overhang the screen edge — only the drawn content has to
        // stay visible, which is what buys the extra travel.
        let sideInset = (windowWidth - BearOverlayWindowController.contentWidth) / 2
        let contentMinX = bounds.lowerBound + sideInset
        let contentMaxX = bounds.upperBound + sideInset + BearOverlayWindowController.contentWidth
        #expect(contentMinX >= visibleFrame.minX)
        #expect(contentMaxX <= visibleFrame.maxX)

        // The corridor has to be wide enough that flights actually read as left/right,
        // rather than every flight collapsing toward the middle of the screen.
        #expect(bounds.upperBound - bounds.lowerBound > visibleFrame.width * 0.4)
    }

}
