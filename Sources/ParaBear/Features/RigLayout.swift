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
@MainActor
enum RigLayout {
    /// Much wider than the rig on purpose; the padding is off-screen travel.
    static let windowSize = CGSize(width: 500, height: 460)
    /// The gap above the canopy, from `BearOverlayView`'s `.padding(.top, 18)`.
    static let cardTopInset: CGFloat = 18
    static let linesHeight: CGFloat = 118
    /// The bear's height follows from its own artwork rather than being stated again here — at
    /// this width the crop wants 192.77, and the 192 that used to sit here disagreed with the box
    /// the bear actually filled.
    static let bearSize = CGSize(width: 106, height: BearCharacterView.height(forWidth: 106))

    static let cardWidth: CGFloat = ParachuteEventCard.width
    /// The card states its own height from the same canopy crop; taking it from there rather than
    /// recomputing keeps `canopyRect` the box the card is actually drawn in.
    static let canopyHeight: CGFloat = ParachuteEventCard.height

    // MARK: - Where each part lands, measured down from the top of the window

    /// The canopy's box. The dome does not fill it — the corners either side are sky — which is why
    /// `contains` tests the canopy's own outline rather than this rectangle.
    static let canopyRect: CGRect = {
        CGRect(
            x: (windowSize.width - cardWidth) / 2,
            y: cardTopInset,
            width: cardWidth,
            height: canopyHeight
        )
    }()

    /// The suspension lines, pulled up so their tops land on the hem.
    static let linesRect: CGRect = {
        CGRect(
            x: canopyRect.minX,
            y: canopyRect.maxY - RiggingLines.hemOverlap(forWidth: cardWidth),
            width: cardWidth,
            height: linesHeight
        )
    }()

    static let bearRect: CGRect = {
        CGRect(
            x: (windowSize.width - bearSize.width) / 2,
            y: linesRect.maxY - RiggingLines.bearOverlap,
            width: bearSize.width,
            height: bearSize.height
        )
    }()

    /// How far the greeting is held off the bear.
    ///
    /// It clears the bear **entirely**, and that is the constraint the bubble's width is chosen
    /// against rather than a nicety: the greeting is a label about the bear, and one drawn across
    /// its face hides the thing it is labelling. It used to overlap because the bubble was placed
    /// so the tail's tip touched the muzzle — but the capsule's right end reaches further right
    /// than the tip does (the tail meets the body about a tenth of the width in from that end), so
    /// aiming the tip at the bear necessarily puts the body over it. The trailing edge is what gets
    /// placed, and the tail points at the bear from just outside it.
    /// Small on purpose. It is measured against `bearRect`, which is the bear's whole box — the
    /// drawn bear is narrower than that almost everywhere — so a few points here still leaves real
    /// space between the tail and the fur, and `theGreetingCoversNoPartOfTheBear` is what keeps
    /// "close" from becoming "on top of".
    static let greetingClearance: CGFloat = 3

    /// How far down the bear's box the tail aims. Level with its head, so the bubble reads as
    /// coming from the bear rather than from the rigging above it.
    static let greetingAim: CGFloat = 32

    /// The greeting bubble's box, when it is showing.
    ///
    /// It lives here rather than on `BearOverlayView` for the reason the rest of this file does:
    /// it is stated in the same coordinates, it is positioned off `bearRect`, and the window — not
    /// the view — is what has to reason about where it is.
    static var greetingRect: CGRect {
        CGRect(
            x: bearRect.minX - greetingClearance - BearGreetingBubble.width,
            y: bearRect.minY + greetingAim - BearGreetingBubble.height,
            width: BearGreetingBubble.width,
            height: BearGreetingBubble.height
        )
    }

    // MARK: - How far it wanders from there

    /// The canopy leans as well as drifting, about the bottom of the lines, so its crown swings
    /// further than the rig's own travel carries it. This is the one allowance the region carries:
    /// the drift and the bear's lean are reported live in the `RigPose`, so they need no headroom,
    /// but the canopy's lean is not (it is 3.2 degrees at most, and covering it costs a margin
    /// thinner than the fabric's shadow).
    ///
    /// It is sized for the rig's **normal** motion — `.windy` at intensity 1 — and not for the
    /// extremes the settings permit, which is a deliberate trade. Covering `.stormy` at intensity
    /// 1.6 takes the region to 442 of the window's 500 points wide, which gives back most of what
    /// this exists to fix. At those settings the very end of a hard swing can put the bear's feet a
    /// few points outside; the cost is having to grab it a moment later, against blocking most of
    /// the screen the whole time.
    static let canopyLeanReach: CGFloat =
        (canopyRect.height + linesHeight) * CGFloat(sin(RigSway.canopyLeanDegrees * .pi / 180))

    // MARK: - The region the window answers for

    /// The dome's own outline **at rest**, and the same outline widened a little.
    ///
    /// Both are frozen once. A `Path` built from a stroke does not hold on to a `CGPath`, so asking
    /// a freshly stroked path whether it contains a point re-strokes fourteen cubic segments every
    /// time — which, on the drift loop, is sixty times a second for a shape that never changes.
    /// Rebuilding it through `cgPath` is what makes the query cheap; caching the `Path` alone buys
    /// nothing.
    ///
    /// The margin is outset by **stroking** rather than by drawing the dome into a bigger box:
    /// `ParachuteCanopy` scales uniformly off the rect's *width*, so a box grown by different
    /// amounts in x and y puts the dome somewhere the drawn one is not, and real fabric ends up
    /// outside the region.
    static let restingCanopyOutline = ParachuteCanopy().path(in: canopyRect)

    static let restingCanopyMargin = Path(
        restingCanopyOutline
            .strokedPath(StrokeStyle(lineWidth: (canopyLeanReach + grabMargin) * 2, lineJoin: .round))
            .cgPath
    )

    /// The suspension lines at rest: the hem's full width at the top, gathering to the knot they
    /// all meet at. A box would be mostly the empty triangles either side of the fan.
    static let restingLinesOutline: Path = {
        let box = linesRect
        let knotWidth = bearSize.width / 2

        var path = Path()
        path.move(to: CGPoint(x: box.minX - grabMargin, y: box.minY - grabMargin))
        path.addLine(to: CGPoint(x: box.maxX + grabMargin, y: box.minY - grabMargin))
        path.addLine(to: CGPoint(x: box.midX + knotWidth, y: box.maxY))
        path.addLine(to: CGPoint(x: box.midX - knotWidth, y: box.maxY))
        path.closeSubpath()

        return path
    }()

    /// A couple of points of slack around everything, so the very edge of the artwork is still
    /// grabbable and a pointer one pixel off the outline is not treated as a miss.
    static let grabMargin: CGFloat = 3

    /// The pose moved onto the query point instead of onto the shapes.
    ///
    /// The drift is a pure translation, so testing `point - drift` against the resting outline is
    /// exactly testing `point` against the drifted one — two subtractions rather than rebuilding
    /// every path each frame.
    private static func atRest(_ point: CGPoint, _ pose: RigPose) -> CGPoint {
        CGPoint(x: point.x - pose.drift.width, y: point.y - pose.drift.height)
    }

    /// Whether the bear covers this point: its own box, leaning by the angle it is leaning.
    ///
    /// It hangs from the top of its head, so that is the pivot — the same anchor `BearOverlayView`
    /// rotates it about. The point is turned back by the lean and tested against the upright box,
    /// which is the same answer as turning the box and costs no path at all. A box that had to hold
    /// every angle at once would be 78 points wider on each side, for a bear 106 across.
    static func bearCovers(_ point: CGPoint, pose: RigPose) -> Bool {
        let resting = atRest(point, pose)
        let pivot = CGPoint(x: bearRect.midX, y: bearRect.minY)
        let radians = -pose.bearDegrees * .pi / 180
        let dx = resting.x - pivot.x
        let dy = resting.y - pivot.y
        let upright = CGPoint(
            x: pivot.x + dx * cos(radians) - dy * sin(radians),
            y: pivot.y + dx * sin(radians) + dy * cos(radians)
        )

        return bearRect.insetBy(dx: -grabMargin, dy: -grabMargin).contains(upright)
    }

    /// `point` in the hosting view's own (top-left origin, y down) coordinates.
    ///
    /// Tested piece by piece rather than against one combined `Path`. Concatenating subpaths is not
    /// a union: under the non-zero winding rule two overlapping pieces wound opposite ways cancel,
    /// and the overlap here — the body box against the canopy's hem — punched a hole through the
    /// region at exactly the point the two meet.
    static func contains(_ point: CGPoint, pose: RigPose) -> Bool {
        if bearCovers(point, pose: pose) { return true }

        let resting = atRest(point, pose)
        if restingLinesOutline.contains(resting) { return true }

        // The canopy's margin is stroked, so it grows the same amount in every direction — but the
        // lean it is there for swings the crown *sideways*. Rotating 3 degrees lifts it by a third
        // of a point, so the strip above the canopy is empty sky and takes no clicks.
        guard resting.y >= canopyRect.minY - grabMargin else { return false }

        return restingCanopyOutline.contains(resting) || restingCanopyMargin.contains(resting)
    }

    /// What the region spans at rest, for checking it is in fact much smaller than the window.
    static var bounds: CGRect {
        restingCanopyMargin.boundingRect
            .union(restingLinesOutline.boundingRect)
            .union(bearRect.insetBy(dx: -grabMargin, dy: -grabMargin))
    }
}
