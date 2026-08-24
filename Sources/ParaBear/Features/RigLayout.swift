import SwiftUI

/// Where the rig sits inside the overlay window, stated once because two things need it.
///
/// `BearOverlayView` needs it to stack the parts. The window needs it for the opposite reason: to
/// know where the rig is **not**, so a click there can fall through to the desktop. The window is
/// 500 wide only so the rig can hang off a screen edge — see
/// `BearOverlayWindowController.centerTravelBounds` — and the rig it draws is 244 at its widest,
/// so more than half of the window is empty air over somebody's desktop.
///
/// That the window has to be told at all is a SwiftUI limitation worth recording: `NSHostingView`
/// answers `hitTest` with itself for **every** point inside its bounds, even where the content is
/// `Color.clear`. SwiftUI's own hit testing — `contentShape`, and gestures — decides which *view*
/// receives an event that already belongs to the window, and never lets one go. So `contentShape`
/// cannot make the window transparent, and the region below is what does.
enum RigLayout {
    /// Much wider than the rig on purpose; the padding is off-screen travel.
    static let windowSize = CGSize(width: 500, height: 460)
    /// The gap above the canopy, from `BearOverlayView`'s `.padding(.top, 18)`.
    static let cardTopInset: CGFloat = 18
    static let linesHeight: CGFloat = 118
    static let bearSize = CGSize(width: 106, height: 192)

    static var cardWidth: CGFloat { ParachuteEventCard.width }
    static var canopyHeight: CGFloat { ParachuteCanopy.height(forWidth: cardWidth) }

    // MARK: - Where each part lands, measured down from the top of the window

    /// The canopy's box. The dome does not fill it — the corners either side are sky — which is why
    /// `hitRegion` tests the canopy's own outline rather than this rectangle.
    static var canopyRect: CGRect {
        CGRect(
            x: (windowSize.width - cardWidth) / 2,
            y: cardTopInset,
            width: cardWidth,
            height: canopyHeight
        )
    }

    /// The suspension lines, pulled up so their tops land on the hem.
    static var linesRect: CGRect {
        CGRect(
            x: canopyRect.minX,
            y: canopyRect.maxY - RiggingLines.hemOverlap(forWidth: cardWidth),
            width: cardWidth,
            height: linesHeight
        )
    }

    static var bearRect: CGRect {
        CGRect(
            x: (windowSize.width - bearSize.width) / 2,
            y: linesRect.maxY - RiggingLines.bearOverlap,
            width: bearSize.width,
            height: bearSize.height
        )
    }

    // MARK: - How far it wanders from there

    /// The allowances below are sized for the rig's **normal** motion — `.windy` at intensity 1 —
    /// and not for the extremes the settings permit, which is a deliberate trade. Covering
    /// `.stormy` at intensity 1.6 takes the region to 442 of the window's 500 points wide, which
    /// gives back most of what this exists to fix. At those settings the very end of a hard swing
    /// can put the bear's feet a few points outside; the cost is having to grab it a moment later,
    /// against blocking most of the screen the whole time.

    /// How far the in-place drift carries the rig sideways.
    static var driftReach: CGFloat {
        CGFloat(RigSway.strokeAmplitude + RigSway.wanderAmplitude)
    }

    /// And how far it floats up and down.
    static var bobReach: CGFloat { CGFloat(RigSway.bobAmplitude) }

    /// How far the bear's feet swing sideways. It rotates about its **top**, so the displacement at
    /// the bottom is its whole height times the sine of the angle — much the largest correction
    /// here, and the reason the region is wider low down than the bear is.
    ///
    /// Sized on both rules added. That sum is a bound the swing approaches and never quite reaches
    /// — the two are 90 degrees out of phase — so this is a little generous, which is the right
    /// direction to be wrong in: too small and the bear is briefly unclickable at the end of a
    /// stroke, and *which* strokes reach furthest depends on the flight's random phase.
    static var swingReach: CGFloat {
        let degrees = BearSwing.trailDegrees + BearSwing.turnDegrees

        return bearSize.height * CGFloat(sin(degrees * .pi / 180))
    }

    /// The canopy leans as well as drifting, about the bottom of the lines, so its crown swings
    /// further than the rig's own travel carries it.
    static var canopyLeanReach: CGFloat {
        (canopyRect.height + linesHeight)
            * CGFloat(sin(RigSway.canopyLeanDegrees * .pi / 180))
    }

    // MARK: - The region the window answers for

    /// Everything the rig can cover, and nothing else.
    ///
    /// Two pieces. The canopy contributes its **drawn outline**, so the two large corners of sky
    /// either side of the dome fall through. Below it, one box wide enough to hold the lines and
    /// the bear at full swing — the bear is only 106 across but its feet reach much further, and a
    /// bear that cannot be grabbed at the end of a stroke would be worse than a slightly generous
    /// box.
    /// The dome's own outline, where it is drawn right now.
    static func canopyOutline(_ pose: RigPose) -> Path {
        ParachuteCanopy().path(
            in: canopyRect.offsetBy(dx: pose.drift.width, dy: pose.drift.height)
        )
    }

    /// And the same outline widened a little. Outset by stroking rather than by drawing the dome
    /// into a bigger box: `ParachuteCanopy` scales uniformly off the rect's *width*, so a box grown
    /// by different amounts in x and y puts the dome somewhere the drawn one is not, and real
    /// fabric ends up outside the region.
    ///
    /// The canopy's own lean is not reported in the pose — it is 3.2 degrees at most, and covering
    /// it costs a margin thinner than the fabric's shadow.
    static func canopyMargin(_ pose: RigPose) -> Path {
        canopyOutline(pose).strokedPath(
            StrokeStyle(lineWidth: (canopyLeanReach + grabMargin) * 2, lineJoin: .round)
        )
    }

    /// The bear where it is right now: its own box, leaning by the angle it is leaning, moved by
    /// the drift the whole rig is under.
    ///
    /// It hangs from the top of its head, so that is the pivot — the same anchor
    /// `BearOverlayView` rotates it about. A box that had to hold every angle at once would be
    /// `swingReach` wider on each side, which is 78 points either way for a bear 106 across.
    static func bearOutline(_ pose: RigPose) -> Path {
        let box = bearRect.offsetBy(dx: pose.drift.width, dy: pose.drift.height)
        let pivot = CGPoint(x: box.midX, y: box.minY)
        let lean = CGAffineTransform(translationX: pivot.x, y: pivot.y)
            .rotated(by: pose.bearDegrees * .pi / 180)
            .translatedBy(x: -pivot.x, y: -pivot.y)

        return Path(box.insetBy(dx: -grabMargin, dy: -grabMargin)).applying(lean)
    }

    /// The suspension lines: the hem's full width at the top, gathering to the knot they all meet
    /// at. A box would be mostly the empty triangles either side of the fan.
    static func linesOutline(_ pose: RigPose) -> Path {
        let box = linesRect.offsetBy(dx: pose.drift.width, dy: pose.drift.height)
        let knotWidth = bearSize.width / 2

        var path = Path()
        path.move(to: CGPoint(x: box.minX - grabMargin, y: box.minY - grabMargin))
        path.addLine(to: CGPoint(x: box.maxX + grabMargin, y: box.minY - grabMargin))
        path.addLine(to: CGPoint(x: box.midX + knotWidth, y: box.maxY))
        path.addLine(to: CGPoint(x: box.midX - knotWidth, y: box.maxY))
        path.closeSubpath()

        return path
    }

    /// A couple of points of slack around everything, so the very edge of the artwork is still
    /// grabbable and a pointer one pixel off the outline is not treated as a miss.
    static let grabMargin: CGFloat = 3

    /// `point` in the hosting view's own (top-left origin, y down) coordinates.
    ///
    /// Tested piece by piece rather than against one combined `Path`. Concatenating subpaths is not
    /// a union: under the non-zero winding rule two overlapping pieces wound opposite ways cancel,
    /// and the overlap here — the body box against the canopy's hem — punched a hole through the
    /// region at exactly the point the two meet.
    static func contains(_ point: CGPoint, pose: RigPose = .resting) -> Bool {
        if bearOutline(pose).contains(point) { return true }
        if linesOutline(pose).contains(point) { return true }

        // The canopy's margin is stroked, so it grows the same amount in every direction — but the
        // lean it is there for swings the crown *sideways*. Rotating 3 degrees lifts it by a third
        // of a point, so the strip above the canopy is empty sky and takes no clicks.
        guard point.y >= canopyRect.minY + pose.drift.height - grabMargin else { return false }

        return canopyOutline(pose).contains(point) || canopyMargin(pose).contains(point)
    }

    /// What the region spans, for checking it is in fact much smaller than the window.
    static func bounds(_ pose: RigPose = .resting) -> CGRect {
        canopyMargin(pose).boundingRect
            .union(linesOutline(pose).boundingRect)
            .union(bearOutline(pose).boundingRect)
    }
}
