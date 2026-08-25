import AppKit
import Testing
@testable import ParaBear

/// Renders the menu's setting rows to a PNG so the controls can be judged by eye — chiefly whether
/// the switch on "Open at login" and the hand-drawn appearance toggle above it read as belonging to
/// the same menu.
///
/// Off by default, like `CanopySnapshot`: set `PARABEAR_SNAPSHOT` to a directory to write into.
/// Both system appearances are drawn, because unlike the rig the menu follows macOS.
@MainActor
struct MenuBarSnapshot {
    @Test func writesMenuRowsPNG() throws {
        guard let directory = ProcessInfo.processInfo.environment["PARABEAR_SNAPSHOT"] else {
            return
        }

        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            try write(appearance, into: directory)
        }
    }

    private func write(_ appearanceName: NSAppearance.Name, into directory: String) throws {
        let segmented = { (labels: [String], selected: Int) -> NSSegmentedControl in
            let control = NSSegmentedControl(
                labels: labels,
                trackingMode: .selectOne,
                target: nil,
                action: nil
            )
            control.selectedSegment = selected
            return control
        }

        let loginToggle = LoginToggleView(isOn: true)

        let rows = [
            MenuRow.make(
                title: "First reminder",
                control: segmented(ReminderLead.allCases.map(\.title), 1)
            ),
            MenuRow.make(
                title: "Times",
                control: segmented(ReminderCount.allCases.map(\.title), 2)
            ),
            MenuRow.make(
                title: "Drop speed",
                control: segmented(PlannedFlightSpeed.allCases.map(\.title), 2)
            ),
            MenuRow.make(
                title: "Appearance",
                control: AppearanceToggleView(scheme: .dark),
                height: 38,
                rightInset: 12
            ),
            MenuRow.make(title: "Open at login", control: loginToggle, height: 38, rightInset: 12)
        ]

        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        for row in rows {
            row.widthAnchor.constraint(equalToConstant: MenuRow.width).isActive = true
        }
        stack.layoutSubtreeIfNeeded()
        stack.frame = NSRect(origin: .zero, size: stack.fittingSize)

        // Inside a window, and on an opaque ground. AppKit's stock controls draw as empty outlines
        // with no window behind them, and every label here is a grey chosen to sit on a menu — on
        // nothing at all, the light one is invisible.
        let window = NSWindow(
            contentRect: stack.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: appearanceName)
        let ground = NSView(frame: stack.frame)
        ground.wantsLayer = true
        ground.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        ground.addSubview(stack)
        window.contentView = ground
        ground.layoutSubtreeIfNeeded()

        let bitmap = try #require(ground.bitmapImageRepForCachingDisplay(in: ground.bounds))
        ground.cacheDisplay(in: ground.bounds, to: bitmap)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))

        try png.write(
            to: URL(fileURLWithPath: directory)
                .appendingPathComponent("menu-rows-\(appearanceName.rawValue).png")
        )
    }
}
