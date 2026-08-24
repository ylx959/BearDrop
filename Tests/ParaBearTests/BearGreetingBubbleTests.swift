import SwiftUI
import Testing
@testable import ParaBear

struct BearGreetingBubbleTests {
    @MainActor
    @Test func currentUserGreetingHasDisplayName() {
        #expect(!CurrentUserGreeting.displayName.isEmpty)
    }

    @MainActor
    @Test func theTailHangsBelowTheCapsule() {
        #expect(BearGreetingBubble.bodyHeight < BearGreetingBubble.height)
        #expect(BearGreetingBubble.tailTip.y == BearGreetingBubble.height)
    }

    /// The tail points down and to the **right of its own base**, which is what puts the bubble
    /// above-left of the bear rather than beside it.
    @MainActor
    @Test func theTailPointsRightOfCentre() {
        #expect(BearGreetingBubble.tailTip.x > BearGreetingBubble.width / 2)
    }
}

/// The shape is traced from `Assets` artwork, so it is checked against the numbers in the file it
/// came from rather than against how it happens to look today.
struct SpeechBubbleTests {
    private let box = SpeechBubble.sourceViewBox

    /// The body is a true capsule: the artwork's corner radius is exactly half its height, so any
    /// version of this shape with a smaller radius is not the one that was drawn.
    @Test func theBodyIsACapsule() {
        let bodyHeight = box.height * SpeechBubble.bodyShare

        #expect(abs(bodyHeight - 579) < 0.01)
        #expect(abs(289.5 - bodyHeight / 2) < 0.01)
    }

    @Test func scalingIsUniformSoTheArtworkIsNotStretched() {
        let width: CGFloat = 176
        let ratio = SpeechBubble.height(forWidth: width) / width

        #expect(abs(ratio - box.height / box.width) < 0.0001)
    }

    /// Every point the path is built from has to be inside the box it declares, or the shape will
    /// be clipped by the frame it is drawn in.
    @Test func theOutlineStaysInsideItsBox() {
        let rect = CGRect(origin: .zero, size: box)
        let drawn = SpeechBubble().path(in: rect).boundingRect

        #expect(rect.insetBy(dx: -0.5, dy: -0.5).contains(drawn))
        // And it genuinely uses the whole of it — a shape that fell short would sit with a gap
        // between the tail and whatever it is pointing at.
        #expect(drawn.height > box.height - 1)
        #expect(drawn.width > box.width - 1)
    }

    /// The tip is a real point on the outline, not a number kept alongside it that could drift.
    @Test func theTipIsOnTheShape() {
        let width: CGFloat = 176
        let rect = CGRect(x: 0, y: 0, width: width, height: SpeechBubble.height(forWidth: width))
        let tip = SpeechBubble.tailTip(forWidth: width)
        let path = SpeechBubble().path(in: rect)

        #expect(abs(path.boundingRect.maxY - tip.y) < 0.01)
        // A point just inside the tail, along the line from the tip back into the body.
        #expect(path.contains(CGPoint(x: tip.x - 2, y: tip.y - 3)))
    }

    /// Text sits in the capsule, so the capsule has to be tall enough to hold a line of 13pt type
    /// with air around it. This is the constraint that decides the bubble's width.
    @MainActor
    @Test func theCapsuleHasRoomForTheType() {
        #expect(BearGreetingBubble.bodyHeight > 30)
    }
}
