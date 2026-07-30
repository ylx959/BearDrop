import AppKit
import SwiftUI

@MainActor
final class BearOverlayWindowController {
    static let maxTravelFromCenterRatio: CGFloat = 0.46

    /// Width of the widest thing actually drawn in the overlay (the parachute card). The window
    /// is much wider than this, so it can hang off the screen edge by the leftover padding
    /// without clipping the bear — that padding is usable horizontal travel.
    static let contentWidth: CGFloat = 244
    static let contentEdgeMargin: CGFloat = 24
    /// Time constant for smoothing the hand's speed. The pointer is quantised to whole points and
    /// arrives unevenly, so even sampled on a steady clock a raw difference is spiky.
    static let handSpeedSmoothing: TimeInterval = 0.05
    /// Sub-step for the carried swing, so a stalled frame cannot make the pendulum overshoot.
    static let carriedSwingStep: TimeInterval = 1.0 / 240

    private let window: NSPanel
    private let driftState: BearDriftState
    /// Offset from the pointer to the window's origin at the moment it was picked up, held constant
    /// for the rest of the carry so the rig does not jump to centre itself under the cursor.
    private var carryGrabOffset: CGSize?
    /// Where the hand was on the previous swing tick, and how fast it is going. Sampled on the
    /// drift timer rather than from mouse events: a hand holding still sends no events at all, and
    /// a swing with nothing to read would sit frozen mid-tilt.
    private var handX: Double = 0
    private var handVelocity: Double = 0
    private var carriedSwing = CarriedSwing.State.level
    private var driftTimer: Timer?
    /// Whether a flight is in the air, and whether one is waiting behind it.
    private var queue = FlightQueue()
    /// The flight is read off its own clock, not the wall's — see `FlightClock`. Opening the menu
    /// stops the drift timer dead, and this is what makes the rig carry on from where it stopped
    /// instead of jumping to where it would have been.
    private var clock = FlightClock(startingAt: Date())
    private var baseX: CGFloat = 0
    private var flightDuration: TimeInterval = PlannedFlightSpeed.fast.flightDuration
    private var verticalSpeed: CGFloat = 0
    private var sway = DescentSway(
        strokeAmplitude: 0, strokeRate: 1, strokePhase: 0,
        wanderAmplitude: 0, wanderRate: 1, wanderPhase: 0
    )

    init<Content: View>(rootView: Content, driftState: BearDriftState) {
        self.driftState = driftState

        let contentView = NSHostingView(rootView: rootView)
        contentView.frame = NSRect(x: 0, y: 0, width: 500, height: 460)
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor

        window = NSPanel(
            contentRect: contentView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.contentView = contentView
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = false
        // Needed for hover tracking to reach the bear: this is a non-activating panel in an
        // accessory app, so it is rarely the active window.
        window.acceptsMouseMovedEvents = true
        window.isMovableByWindowBackground = false
        window.hidesOnDeactivate = false
        positionAtTopEdge()

        driftState.onCarry = { [weak self] point in self?.carry(toScreenPoint: point) }
        driftState.onDrop = { [weak self] in self?.dropAndResumeDescent() }
    }

    /// Flies, or waits its turn — see `FlightQueue`. A flight already in the air is never cut
    /// short, and one being carried is never taken out of the hand carrying it.
    func playReminderFlight(duration: TimeInterval) {
        guard let now = queue.request(duration) else { return }

        beginFlight(duration: now)
    }

    func hide() {
        queue.cancel()
        stop()
    }

    private func beginFlight(duration: TimeInterval) {
        flightDuration = duration
        positionAboveTopEdge()
        window.orderFrontRegardless()
        startOneShotDrift()
    }

    /// The flight has left the bottom of the screen. Whatever was waiting behind it goes now.
    private func finishFlight() {
        stop()

        if let next = queue.finished() {
            beginFlight(duration: next)
        }
    }

    private func stop() {
        driftTimer?.invalidate()
        driftTimer = nil
        window.orderOut(nil)
    }

    private func positionAtTopEdge() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let size = window.frame.size
        baseX = Self.centeredOriginX(visibleFrame: frame, windowWidth: size.width)
        let origin = NSPoint(
            x: baseX,
            y: frame.maxY - size.height - 72
        )
        window.setFrameOrigin(origin)
    }

    private func positionAboveTopEdge() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        resetFlight()

        placeFlight(visibleFrame: visibleFrame)

        window.setFrameOrigin(
            NSPoint(x: baseX + CGFloat(sway.offset(at: 0)), y: visibleFrame.maxY + 12)
        )
    }

    /// Sizes the sweep to the corridor, then places the flight so the whole sweep fits with room
    /// to spare. Sizing first and placing second is deliberate: `baseX` is fixed for the flight, so
    /// all the visible side-to-side travel comes from the sweep. Picking the position first and
    /// shrinking the sweep to fit starves it toward zero whenever the position lands off-centre,
    /// which reads on screen as the bear barely moving sideways at all.
    ///
    /// Because the sweep is sized to fit, nothing downstream ever has to hold it back — and a
    /// held-back sweep was what used to leave the bear leaning against travel that had stopped.
    private func placeFlight(visibleFrame: NSRect, centredOn dropX: CGFloat? = nil) {
        let travelBounds = Self.centerTravelBounds(
            visibleFrame: visibleFrame,
            windowWidth: window.frame.width
        )
        let screenWidth = Double(visibleFrame.width)

        guard let dropX else {
            let room = Double(travelBounds.upperBound - travelBounds.lowerBound) / 2
            sway = DescentSway.random(
                room: room,
                screenWidth: screenWidth,
                flightDuration: flightDuration
            )
            let reach = CGFloat(sway.reach)
            let lower = travelBounds.lowerBound + reach
            let upper = travelBounds.upperBound - reach
            baseX = lower < upper
                ? CGFloat.random(in: lower...upper)
                : (travelBounds.lowerBound + travelBounds.upperBound) / 2
            return
        }

        // Resuming from a drop, the centre is already decided, so the sweep gets whatever room is
        // actually left on the tighter side. Sizing it against the whole corridor instead would let
        // a bear dropped near an edge sweep straight off the screen.
        let centre = min(max(dropX, travelBounds.lowerBound), travelBounds.upperBound)
        let room = Double(min(centre - travelBounds.lowerBound, travelBounds.upperBound - centre))
        sway = DescentSway.startingLevel(
            room: room,
            screenWidth: screenWidth,
            flightDuration: flightDuration
        )
        baseX = centre
    }

    private func startOneShotDrift() {
        driftTimer?.invalidate()
        clock.restart(at: Date())
        verticalSpeed = pointsPerSecondForCurrentFlight()
        driftTimer = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceDrift()
            }
        }
    }

    private func advanceDrift() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        // The window is driven straight from the pointer's own events while it is being carried, so
        // the drift loop must keep its hands off it entirely — but it still drives the swing, and
        // the clock still takes the frame so a long carry cannot bank time and spend it on release.
        let dt = clock.frame(at: Date(), running: !driftState.isBeingCarried)

        if driftState.isBeingCarried {
            advanceCarriedSwing(dt: dt)
            return
        }

        let elapsed = clock.elapsed

        let travelBounds = Self.centerTravelBounds(
            visibleFrame: visibleFrame,
            windowWidth: window.frame.width
        )
        var origin = window.frame.origin
        // The sweep is sized to fit inside the corridor, so this never bites. It is a backstop for
        // screens too narrow to hold a sweep at all, where a clipped position beats an off-screen
        // card — and it is deliberately not fed back into the swing, because a lean that snaps to
        // level whenever the window touches a wall is exactly what used to look wrong.
        origin.x = min(
            max(baseX + CGFloat(sway.offset(at: elapsed)), travelBounds.lowerBound),
            travelBounds.upperBound
        )

        // Published rather than turned into an angle here: the drift drawn inside the window is
        // travel too, and the bear has one lean, so the view adds the two and applies the rules
        // once. Read at the same instant as the position, exactly as the in-place drift is.
        driftState.carriedSwingDegrees = nil
        driftState.descentTravel = BearSwing.Travel(
            velocity: sway.velocity(at: elapsed),
            acceleration: sway.acceleration(at: elapsed),
            nominalSpeed: sway.nominalSpeed(at: elapsed),
            nominalTurn: sway.nominalTurn(at: elapsed)
        )

        origin.y -= verticalSpeed * CGFloat(dt)

        if origin.y + window.frame.height < visibleFrame.minY - 40 {
            finishFlight()
            return
        }

        window.setFrameOrigin(origin)
    }

    /// Follows the pointer. Called from the drag gesture itself rather than from the drift timer,
    /// so the rig keeps up with the hand at whatever rate the mouse reports instead of stepping
    /// along at 30fps. The window goes exactly where it is put, anywhere on screen, and the descent
    /// is suspended until it is let go.
    private func carry(toScreenPoint point: CGPoint) {
        guard let grabOffset = carryGrabOffset else {
            let origin = window.frame.origin
            carryGrabOffset = CGSize(width: origin.x - point.x, height: origin.y - point.y)
            handX = Double(point.x)
            handVelocity = 0
            return
        }

        window.setFrameOrigin(
            NSPoint(x: point.x + grabOffset.width, y: point.y + grabOffset.height)
        )
    }

    /// Keeps the carried swing moving on the drift timer's steady clock. Deliberately separate from
    /// `carry(toScreenPoint:)`: the window has to follow the pointer at the pointer's own rate, but
    /// the swing has to keep integrating even on the frames — or seconds — where the hand does not
    /// move at all, which is exactly when a rule read off the motion would freeze.
    private func advanceCarriedSwing(dt: TimeInterval) {
        guard dt > 0 else { return }

        let x = Double(NSEvent.mouseLocation.x)
        let sampledSpeed = (x - handX) / dt
        handX = x

        let previousVelocity = handVelocity
        handVelocity += (sampledSpeed - handVelocity) * min(1, dt / Self.handSpeedSmoothing)
        let handAcceleration = (handVelocity - previousVelocity) / dt

        var remaining = dt
        while remaining > 0 {
            let step = min(Self.carriedSwingStep, remaining)
            carriedSwing = CarriedSwing.advance(
                carriedSwing,
                handVelocity: handVelocity,
                handAcceleration: handAcceleration,
                dt: step
            )
            remaining -= step
        }

        driftState.carriedSwingDegrees = carriedSwing.degrees
    }

    /// Picks the descent back up from wherever the bear was put down: the drop position becomes the
    /// new centre of the sway, so it carries on from there instead of sliding back to where it was.
    private func dropAndResumeDescent() {
        guard let screen = NSScreen.main else { return }

        carryGrabOffset = nil
        handVelocity = 0
        carriedSwing = .level
        // The drop point becomes where this flight's sweep is centred, and the sweep starts level
        // there, so the descent carries on from where it was put down without a jump.
        placeFlight(visibleFrame: screen.visibleFrame, centredOn: window.frame.origin.x)
        clock.restart(at: Date())
    }

    private func pointsPerSecondForCurrentFlight() -> CGFloat {
        guard let screen = NSScreen.main else { return 44 }
        let travelDistance = screen.visibleFrame.height + window.frame.height + 72
        return travelDistance / CGFloat(flightDuration)
    }

    private func resetFlight() {
        carryGrabOffset = nil
        handVelocity = 0
        carriedSwing = .level
        driftState.reset()
    }

    static func centeredOriginX(visibleFrame: NSRect, windowWidth: CGFloat) -> CGFloat {
        visibleFrame.midX - windowWidth / 2
    }

    static func centerTravelBounds(visibleFrame: NSRect, windowWidth: CGFloat) -> ClosedRange<CGFloat> {
        let centerX = centeredOriginX(visibleFrame: visibleFrame, windowWidth: windowWidth)
        let travel = visibleFrame.width * maxTravelFromCenterRatio
        // Bound the visible content, not the window. The window's empty side padding may sit
        // off-screen, which is what lets the bear reach much further left and right.
        let sideInset = max(0, (windowWidth - contentWidth) / 2)
        let screenMinX = visibleFrame.minX + contentEdgeMargin - sideInset
        let screenMaxX = visibleFrame.maxX - windowWidth - contentEdgeMargin + sideInset
        let lower = max(screenMinX, centerX - travel)
        let upper = min(screenMaxX, centerX + travel)

        return lower <= upper ? lower...upper : centerX...centerX
    }

}
