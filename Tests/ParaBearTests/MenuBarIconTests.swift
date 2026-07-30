import AppKit
import Testing
@testable import ParaBear

@MainActor
struct MenuBarIconTests {
    /// The menu bar tints its own icons — light bar, dark bar, and inverted again while the menu is
    /// open. An icon that is not a template opts out of all three and sits there in one colour.
    @Test func theIconIsATemplateSoTheMenuBarCanTintIt() throws {
        let icon = try #require(MenuBarIcon.pawCalendar())

        #expect(icon.isTemplate)
        #expect(icon.size == MenuBarIcon.size)
    }

    /// `NSImage.draw(in:)` stretches to whatever rect it is given, and a pawprint is not square.
    /// Dropped straight into the square badge it came out squashed.
    @Test func theBadgeKeepsThePawsProportions() {
        let box = NSRect(x: 8, y: 0, width: 10, height: 10)
        let fitted = MenuBarIcon.fit(NSSize(width: 30, height: 20), in: box)

        #expect(abs(fitted.width / fitted.height - 1.5) < 1e-9)
        #expect(fitted.width <= box.width + 1e-9)
        #expect(fitted.height <= box.height + 1e-9)
        #expect(abs(fitted.midX - box.midX) < 1e-9)
        #expect(abs(fitted.midY - box.midY) < 1e-9)
    }

    /// A zero-sized symbol — one that failed to load — must not divide by zero on the way in.
    @Test func aSymbolWithNoSizeFallsBackToTheBoxItWasGiven() {
        let box = NSRect(x: 0, y: 0, width: 10, height: 10)

        #expect(MenuBarIcon.fit(.zero, in: box) == box)
    }
}
