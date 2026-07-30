import AppKit
import Combine

@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let settings: SettingsStore
    private let calendarService: CalendarService
    private let onCallBear: () -> Void
    private let onOpenSettings: () -> Void
    private var cancellables: Set<AnyCancellable> = []
    private let statusDot = NSView(frame: NSRect(x: 0, y: 0, width: 8, height: 8))
    private let statusLabel = NSTextField(labelWithString: "Calendar connecting")
    private let speedControl = NSSegmentedControl(
        labels: PlannedFlightSpeed.allCases.map(\.title),
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let appearanceToggle: AppearanceToggleView

    init(
        settings: SettingsStore,
        calendarService: CalendarService,
        onCallBear: @escaping () -> Void,
        onHideBear: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.settings = settings
        self.calendarService = calendarService
        self.onCallBear = onCallBear
        self.onOpenSettings = onOpenSettings
        appearanceToggle = AppearanceToggleView(scheme: settings.appearance)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = MenuBarIcon.pawCalendar()
            button.imagePosition = .imageOnly
        }

        let menu = NSMenu()
        menu.addItem(customItem(view: statusRow()))
        menu.addItem(customItem(view: speedRow()))
        menu.addItem(customItem(view: appearanceRow()))
        menu.addItem(NSMenuItem.separator())

        // "Call", not "Test": this flies the bear with whatever is actually in the next hour on
        // it, so it is a way to ask the bear what is coming — not a rehearsal of one.
        let callItem = NSMenuItem(title: "Call ParaBear", action: #selector(callBear), keyEquivalent: "")
        callItem.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Call ParaBear")
        callItem.target = self
        menu.addItem(callItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit ParaBear", action: #selector(quit), keyEquivalent: "q")
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: "Quit ParaBear")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        bindCalendarStatus()

        // The toggle is built once but the setting it shows is not only ours to change, so it
        // follows the store rather than assuming it is the only thing writing to it.
        settings.$appearance
            .sink { [weak self] appearance in
                self?.appearanceToggle.setScheme(appearance)
            }
            .store(in: &cancellables)
    }

    private func statusRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 7
        row.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 7, right: 12)
        row.frame = NSRect(x: 0, y: 0, width: 210, height: 30)

        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 4
        statusDot.setContentHuggingPriority(.required, for: .horizontal)
        statusDot.widthAnchor.constraint(equalToConstant: 8).isActive = true
        statusDot.heightAnchor.constraint(equalToConstant: 8).isActive = true

        statusLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        statusLabel.textColor = .labelColor
        row.addArrangedSubview(statusDot)
        row.addArrangedSubview(statusLabel)
        return row
    }

    private func speedRow() -> NSView {
        let title = NSTextField(labelWithString: "Planned speed")
        title.font = .systemFont(ofSize: 11, weight: .medium)
        title.textColor = .secondaryLabelColor

        speedControl.segmentStyle = .rounded
        speedControl.target = self
        speedControl.action = #selector(speedChanged)
        speedControl.selectedSegment = PlannedFlightSpeed.allCases.firstIndex(of: settings.plannedFlightSpeed) ?? 2
        speedControl.controlSize = .small

        let row = NSStackView(views: [title, speedControl])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 12
        row.edgeInsets = NSEdgeInsets(top: 4, left: 12, bottom: 8, right: 10)
        row.frame = NSRect(x: 0, y: 0, width: 210, height: 34)
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)
        speedControl.setContentHuggingPriority(.required, for: .horizontal)
        return row
    }

    private func appearanceRow() -> NSView {
        let title = NSTextField(labelWithString: "Appearance")
        title.font = .systemFont(ofSize: 11, weight: .medium)
        title.textColor = .secondaryLabelColor

        appearanceToggle.onChange = { [weak self] appearance in
            self?.settings.appearance = appearance
        }

        let row = NSStackView(views: [title, appearanceToggle])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 12
        row.edgeInsets = NSEdgeInsets(top: 4, left: 12, bottom: 8, right: 12)
        row.frame = NSRect(x: 0, y: 0, width: 210, height: 38)
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)
        appearanceToggle.setContentHuggingPriority(.required, for: .horizontal)
        return row
    }

    private func customItem(view: NSView) -> NSMenuItem {
        let item = NSMenuItem()
        item.view = view
        return item
    }

    private func bindCalendarStatus() {
        calendarService.$authorizationState
            .sink { [weak self] state in
                self?.updateCalendarStatus(state)
            }
            .store(in: &cancellables)
        updateCalendarStatus(calendarService.authorizationState)
    }

    private func updateCalendarStatus(_ state: CalendarService.AuthorizationState) {
        switch state {
        case .authorized:
            statusDot.layer?.backgroundColor = NSColor.systemGreen.cgColor
            statusLabel.stringValue = "Calendar connected"
        case .denied:
            statusDot.layer?.backgroundColor = NSColor.systemRed.cgColor
            statusLabel.stringValue = "Calendar unavailable"
        case .unknown:
            statusDot.layer?.backgroundColor = NSColor.systemYellow.cgColor
            statusLabel.stringValue = "Calendar connecting"
        }
    }

    @objc private func callBear() {
        onCallBear()
    }

    @objc private func speedChanged() {
        let index = speedControl.selectedSegment
        guard PlannedFlightSpeed.allCases.indices.contains(index) else { return }
        settings.plannedFlightSpeed = PlannedFlightSpeed.allCases[index]
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
