import Foundation

/// Bridges the overlay window's live motion to the SwiftUI bear, in both directions.
///
/// The window's drift is integrated in `BearOverlayWindowController`, but the bear is drawn by
/// SwiftUI, so without this the bear has no idea the rig is moving and cannot react to it — and
/// the controller has no idea the pointer has picked the rig up and is carrying it somewhere.
///
/// `descentTravel` is read every frame from inside a `TimelineView(.animation)`, which already
/// re-renders each frame, so a plain stored property is enough and publishing would only add
/// churn. Carrying goes the other way and is a *callback* rather than a stored value on
/// purpose: the window has to move on the same event that moved the pointer, not on the drift
/// timer's next tick, or the drag visibly trails the hand.
@MainActor
final class BearDriftState {
    /// The descent's own horizontal travel, published for the view to combine with the drift it
    /// draws itself. Travel rather than a finished angle, because the bear has a single lean and
    /// the rules have to be applied once to everything moving it — see `BearSwing.Travel`.
    var descentTravel = BearSwing.Travel.still

    /// While the pointer is carrying the rig there is no curve to read, so the swing comes from
    /// `CarriedSwing` as a finished angle and overrides the rules entirely.
    var carriedSwingDegrees: Double?

    private(set) var isBeingCarried = false

    /// Where the pointer is on screen, in screen coordinates.
    ///
    /// Screen coordinates and not the gesture's own translation, which is measured in the view's
    /// space — and the view travels with the window. Moving the window to follow that translation
    /// puts the pointer back where it started relative to the view, the translation collapses to
    /// zero, and the rig fights the hand instead of following it.
    var onCarry: ((CGPoint) -> Void)?
    var onDrop: (() -> Void)?

    func carry(toScreenPoint point: CGPoint) {
        isBeingCarried = true
        onCarry?(point)
    }

    func drop() {
        guard isBeingCarried else { return }

        isBeingCarried = false
        onDrop?()
    }

    func reset() {
        descentTravel = .still
        carriedSwingDegrees = nil
        isBeingCarried = false
    }
}
