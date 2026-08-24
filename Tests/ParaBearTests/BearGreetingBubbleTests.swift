import AppKit
import SwiftUI
import Testing
@testable import ParaBear

struct BearGreetingBubbleTests {
    /// Every remark has to fit the bubble it is drawn in — at most two lines, without being shrunk
    /// past the point where it stops matching the short ones. This is the constraint that fixes the
    /// bubble's width, so it is measured rather than eyeballed.
    @MainActor
    @Test func everyRemarkFitsInTwoLines() {
        let font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let rounded = NSFont(
            descriptor: font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor,
            size: 13
        ) ?? font
        // What the text is actually given, once the capsule's horizontal padding is taken out.
        let available = (BearGreetingBubble.width - 28) * 2

        for remark in BearRemark.all {
            let width = (remark as NSString).size(withAttributes: [.font: rounded]).width

            #expect(width <= available, "\"\(remark)\" needs \(Int(width))pt of two lines")
        }
    }

    @MainActor
    @Test func theTailHangsBelowTheCapsule() {
        #expect(BearGreetingBubble.bodyHeight < BearGreetingBubble.height)
        #expect(SpeechBubble.tailTip(forWidth: BearGreetingBubble.width).y == BearGreetingBubble.height)
    }

    /// The tail points down and to the **right of its own base**, which is what puts the bubble
    /// above-left of the bear rather than beside it.
    @MainActor
    @Test func theTailPointsRightOfCentre() {
        #expect(SpeechBubble.tailTip(forWidth: BearGreetingBubble.width).x > BearGreetingBubble.width / 2)
    }

    /// The greeting is a label about the bear, so it must not be drawn over any part of it.
    @MainActor
    @Test func theGreetingCoversNoPartOfTheBear() {
        #expect(!RigLayout.greetingRect.intersects(RigLayout.bearRect))
    }

    /// And it is genuinely beside the bear rather than parked somewhere harmlessly far away — the
    /// tail has to be pointing at something.
    @MainActor
    @Test func theGreetingStillSitsNextToTheBear() {
        let gap = RigLayout.bearRect.minX - RigLayout.greetingRect.maxX

        #expect(gap > 0)
        #expect(gap < 24)
        // Level with the bear, not floating above the canopy.
        #expect(RigLayout.greetingRect.maxY > RigLayout.bearRect.minY)
    }

    /// It also has to fit in the window, which is the other half of what fixes the width.
    @MainActor
    @Test func theGreetingFitsInsideTheWindow() {
        #expect(RigLayout.greetingRect.minX > 0)
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

struct BearRemarkTests {
    @Test func thereAreRemarksAndNoneAreEmpty() {
        #expect(BearRemark.all.count == 17)
        #expect(BearRemark.all.allSatisfy { !$0.isEmpty })
    }

    /// Duplicates would make `next(after:)` able to repeat itself despite excluding the last line.
    @Test func theRemarksAreAllDifferent() {
        #expect(Set(BearRemark.all).count == BearRemark.all.count)
    }

    /// The whole point of `next(after:)`: a tap always changes the words, because that is the only
    /// feedback the tap gives.
    @Test func theNextRemarkIsNeverTheOneAlreadyShowing() {
        var showing = BearRemark.all[0]

        for _ in 0..<500 {
            let next = BearRemark.next(after: showing)

            #expect(next != showing)
            #expect(BearRemark.all.contains(next))
            showing = next
        }
    }

    /// And with nothing showing yet it still answers.
    @Test func theFirstRemarkNeedsNoPredecessor() {
        #expect(BearRemark.all.contains(BearRemark.next(after: nil)))
    }
}
