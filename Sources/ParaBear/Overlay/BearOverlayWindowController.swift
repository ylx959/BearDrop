import AppKit
import SwiftUI

@MainActor
final class BearOverlayWindowController {
    private let window: NSPanel
    private var driftTimer: Timer?
    private var driftStartDate = Date()
    private var lastFrameDate = Date()
    private var baseX: CGFloat = 0
    private var flightDuration: TimeInterval = PlannedFlightSpeed.fast.flightDuration
    private var verticalSpeed: CGFloat = 0
    private var swayOffset: CGFloat = 0
    private var swayVelocity: CGFloat = 0
    private var windSeed = Double.random(in: 0...100)
    private var dragMonitor: Any?
    private var isDragging = false
    private var dragStartMouseLocation = NSPoint.zero
    private var dragStartWindowOrigin = NSPoint.zero

    init<Content: View>(rootView: Content) {
        let contentView = NSHostingView(rootView: rootView)
        contentView.frame = NSRect(x: 0, y: 0, width: 340, height: 460)
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
        window.isMovableByWindowBackground = false
        window.hidesOnDeactivate = false
        positionAtTopEdge()
        installDragMonitor()
    }

    func playReminderFlight(duration: TimeInterval) {
        flightDuration = duration
        positionAboveTopEdge()
        window.orderFrontRegardless()
        startOneShotDrift()
    }

    func showPreviewFlight(duration: TimeInterval) {
        playReminderFlight(duration: duration)
    }

    func hide() {
        driftTimer?.invalidate()
        driftTimer = nil
        window.orderOut(nil)
    }

    private func positionAtTopEdge() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let size = window.frame.size
        baseX = frame.maxX - size.width - 48
        let origin = NSPoint(
            x: baseX,
            y: frame.maxY - size.height - 72
        )
        window.setFrameOrigin(origin)
    }

    private func positionAboveTopEdge() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let maxX = max(visibleFrame.minX + 40, visibleFrame.maxX - window.frame.width - 40)
        baseX = CGFloat.random(in: visibleFrame.minX + 40...maxX)
        resetWindSway()
        window.setFrameOrigin(
            NSPoint(
                x: baseX,
                y: visibleFrame.maxY + 12
            )
        )
    }

    private func startOneShotDrift() {
        driftTimer?.invalidate()
        driftStartDate = Date()
        lastFrameDate = driftStartDate
        verticalSpeed = pointsPerSecondForCurrentFlight()
        driftTimer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceDrift()
            }
        }
    }

    private func advanceDrift() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        guard !isDragging else { return }

        let now = Date()
        let elapsed = now.timeIntervalSince(driftStartDate)
        let dt = min(1 / 15, now.timeIntervalSince(lastFrameDate))
        lastFrameDate = now

        integrateWindSway(elapsed: elapsed, dt: dt)
        let lateralDrift = CGFloat(sin(elapsed * 1.45) * 34)
        var origin = window.frame.origin

        origin.x = baseX + swayOffset + lateralDrift * 0.24
        origin.y -= verticalSpeed * CGFloat(dt)

        if origin.y + window.frame.height < visibleFrame.minY - 40 {
            hide()
            return
        }

        window.setFrameOrigin(origin)
    }

    private func pointsPerSecondForCurrentFlight() -> CGFloat {
        guard let screen = NSScreen.main else { return 44 }
        let travelDistance = screen.visibleFrame.height + window.frame.height + 72
        return travelDistance / CGFloat(flightDuration)
    }

    private func resetWindSway() {
        swayOffset = 0
        swayVelocity = 0
        windSeed = Double.random(in: 0...100)
    }

    private func integrateWindSway(elapsed: TimeInterval, dt: TimeInterval) {
        let t = elapsed + windSeed
        let windForce = CGFloat(
            sin(t * 0.72) * 44
            + sin(t * 1.37 + 1.8) * 18
            + sin(t * 2.63 + 0.4) * 7
        )
        let springBack = -0.92 * swayOffset
        let damping = -1.72 * swayVelocity
        let acceleration = springBack + damping + windForce

        swayVelocity += acceleration * CGFloat(dt)
        swayOffset += swayVelocity * CGFloat(dt)
        swayOffset = min(max(swayOffset, -92), 92)
    }

    private func installDragMonitor() {
        dragMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            guard let self else { return event }
            return self.handleDragEvent(event)
        }
    }

    private func handleDragEvent(_ event: NSEvent) -> NSEvent? {
        switch event.type {
        case .leftMouseDown:
            guard event.window === window else { return event }
            isDragging = true
            dragStartMouseLocation = NSEvent.mouseLocation
            dragStartWindowOrigin = window.frame.origin
            return event
        case .leftMouseDragged:
            guard isDragging else { return event }
            let mouseLocation = NSEvent.mouseLocation
            let delta = NSPoint(
                x: mouseLocation.x - dragStartMouseLocation.x,
                y: mouseLocation.y - dragStartMouseLocation.y
            )
            window.setFrameOrigin(
                NSPoint(
                    x: dragStartWindowOrigin.x + delta.x,
                    y: dragStartWindowOrigin.y + delta.y
                )
            )
            return nil
        case .leftMouseUp:
            guard isDragging else { return event }
            isDragging = false
            resumeFlightFromCurrentPosition()
            return event
        default:
            return event
        }
    }

    private func resumeFlightFromCurrentPosition() {
        baseX = window.frame.origin.x
        resetWindSway()
        driftStartDate = Date()
        lastFrameDate = driftStartDate
        verticalSpeed = pointsPerSecondForCurrentFlight()
    }
}
