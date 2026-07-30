import AppKit

/// The status item's icon: a calendar with a pawprint badged onto the corner.
///
/// SF Symbols has no `calendar.badge.pawprint`, so it is composed from the two symbols that do
/// exist. The badge is not simply drawn on top — a hole is punched clear through the calendar
/// first, and the paw sits inside it. That gap is what makes a badge read as a badge: without it
/// the paw's toes and the calendar's grid tangle into a smudge, which at 18 points is all anyone
/// would see. It is the same thing Apple's own `.badge.` symbols do.
///
/// The result stays a **template** image. The menu bar tints its icons itself — light on a dark
/// bar, dark on a light one, and inverted again while the menu is open — and anything with its own
/// colours would sit there ignoring all three.
enum MenuBarIcon {
    /// The menu bar's own scale. Not the symbol's point size: it is the box the finished icon
    /// occupies, and the two symbols are fitted inside it.
    static let size = NSSize(width: 18, height: 18)

    /// How much of the icon the badge takes up, and how wide the clear gap around it is.
    private static let badgeShare: CGFloat = 0.52
    private static let gap: CGFloat = 1.0
    /// How much of the box the calendar keeps once it has made room. A badged symbol is not the
    /// plain symbol with something stuck on it — the system's own shrink the base and move it off
    /// the badged corner, and skipping that step is what leaves the badge eating the calendar's
    /// grid instead of sitting beside it.
    private static let calendarShare: CGFloat = 0.82

    static func pawCalendar() -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: size.height, weight: .regular)

        guard
            let calendar = NSImage(systemSymbolName: "calendar", accessibilityDescription: nil)?
                .withSymbolConfiguration(configuration),
            let paw = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(configuration)
        else {
            return nil
        }

        let badge = badgeRect()
        let hole = badge.insetBy(dx: -gap, dy: -gap)

        let icon = NSImage(size: size, flipped: false) { _ in
            calendar.draw(in: calendarRect(), from: .zero, operation: .sourceOver, fraction: 1)

            // Straight through everything drawn so far, alpha and all.
            NSGraphicsContext.current?.compositingOperation = .clear
            NSBezierPath(ovalIn: hole).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver

            paw.draw(in: fit(paw.size, in: badge), from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }

        icon.isTemplate = true
        icon.accessibilityDescription = "ParaBear"
        return icon
    }

    /// Top-leading, away from the badge.
    private static func calendarRect() -> NSRect {
        let side = size.width * calendarShare

        return NSRect(x: 0, y: size.height - side, width: side, height: side)
    }

    /// The largest rect of `size`'s proportions that fits inside `box`, centred.
    ///
    /// `NSImage.draw(in:)` stretches, and a pawprint is not square — dropped straight into a square
    /// badge it comes out squashed, which at this scale reads as a smudge rather than as a paw.
    static func fit(_ size: NSSize, in box: NSRect) -> NSRect {
        guard size.width > 0, size.height > 0 else { return box }

        let scale = min(box.width / size.width, box.height / size.height)
        let fitted = NSSize(width: size.width * scale, height: size.height * scale)

        return NSRect(
            x: box.midX - fitted.width / 2,
            y: box.midY - fitted.height / 2,
            width: fitted.width,
            height: fitted.height
        )
    }

    /// Bottom-trailing, which is where every badged symbol in the system puts its badge — and the
    /// one corner of a calendar with nothing in it.
    private static func badgeRect() -> NSRect {
        let side = size.width * badgeShare

        return NSRect(
            x: size.width - side,
            y: 0,
            width: side,
            height: side
        )
    }
}
