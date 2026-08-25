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
    private let leadControl = NSSegmentedControl(
        labels: ReminderLead.allCases.map(\.title),
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let countControl = NSSegmentedControl(
        labels: ReminderCount.allCases.map(\.title),
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let reminderSummary = NSTextField(labelWithString: "")
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
        menu.addItem(customItem(view: reminderLeadRow()))
        menu.addItem(customItem(view: reminderCountRow()))
        menu.addItem(customItem(view: reminderSummaryRow()))
        menu.addItem(customItem(view: speedRow()))
        menu.addItem(customItem(view: appearanceRow()))
        menu.addItem(NSMenuItem.separator())

        // "Call", not "Test": this flies the bear with whatever is actually in the next hour on
        // it, so it is a way to ask the bear what is coming — not a rehearsal of one. Which is why
        // the call re-reads the calendar before launching (`EventTimelineViewModel.refreshNow`):
        // an answer up to a poll old is a rehearsal of the last one.
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

        // Either control changes the sentence, so it follows the store rather than being written
        // from the two actions — which would be two places to remember, and one of them would be
        // missed the first time anything else set a reminder preference.
        settings.$reminderLead
            .combineLatest(settings.$reminderCount)
            .sink { [weak self] lead, count in
                self?.reminderSummary.stringValue = ReminderSchedule(lead: lead, count: count).summary
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

    /// How far out the first flight goes, and how many flights the approach gets — the two halves
    /// of a `ReminderSchedule`. They sit above "Drop speed" because *when* the bear arrives is the
    /// part of this that decides whether you make the meeting; how fast it falls is decoration.
    private func reminderLeadRow() -> NSView {
        leadControl.target = self
        leadControl.action = #selector(reminderLeadChanged)
        leadControl.selectedSegment = ReminderLead.allCases.firstIndex(of: settings.reminderLead) ?? 1

        return settingRow(title: "First reminder", control: leadControl)
    }

    private func reminderCountRow() -> NSView {
        countControl.target = self
        countControl.action = #selector(reminderCountChanged)
        countControl.selectedSegment = ReminderCount.allCases.firstIndex(of: settings.reminderCount) ?? 2

        return settingRow(title: "Times", control: countControl)
    }

    /// The two controls above state the *inputs* to the rule — a lead and a count — and leave the
    /// reader to divide one by the other to work out when the bear will actually turn up. This row
    /// states the answer instead, in the same words for every combination, and it is the only part
    /// of the menu that answers the question anyone opening it actually has.
    ///
    /// The text comes from `ReminderSchedule.summary`, which builds it from the very offsets the
    /// flights are made from. A line hand-written here would be a second description of the
    /// schedule, free to disagree with the first.
    private func reminderSummaryRow() -> NSView {
        // Secondary rather than tertiary, which is where a caption would normally sit. This is not
        // a caption: it is the only line in the menu that answers the question the two controls
        // above pose, so it must not be the faintest thing in the block. The regular weight against
        // the rows' medium is what keeps it subordinate without hiding it.
        reminderSummary.font = .systemFont(ofSize: 11, weight: .regular)
        reminderSummary.textColor = .secondaryLabelColor

        let row = NSStackView(views: [reminderSummary])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 9, right: 12)
        row.frame = NSRect(x: 0, y: 0, width: 210, height: 22)
        return row
    }

    /// The shape all three segmented rows share. They were three copies of the same eleven lines,
    /// and three copies are three places for the insets to drift apart.
    private func settingRow(title: String, control: NSSegmentedControl) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor

        control.segmentStyle = .rounded
        control.controlSize = .small

        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 12
        row.edgeInsets = NSEdgeInsets(top: 4, left: 12, bottom: 8, right: 10)
        row.frame = NSRect(x: 0, y: 0, width: 210, height: 34)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.setContentHuggingPriority(.required, for: .horizontal)
        return row
    }

    private func speedRow() -> NSView {
        speedControl.target = self
        speedControl.action = #selector(speedChanged)
        speedControl.selectedSegment = PlannedFlightSpeed.allCases.firstIndex(of: settings.plannedFlightSpeed) ?? 2

        return settingRow(title: "Drop speed", control: speedControl)
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

    /// Opens the menu exactly as clicking the status item does — same highlight, same menu, same
    /// dismissal. Building a second `NSMenu` to pop up elsewhere would be two menus to keep in
    /// agreement; this is the one that is already there.
    func openMenu() {
        statusItem.button?.performClick(nil)
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

    @objc private func reminderLeadChanged() {
        let index = leadControl.selectedSegment
        guard ReminderLead.allCases.indices.contains(index) else { return }
        settings.reminderLead = ReminderLead.allCases[index]
    }

    @objc private func reminderCountChanged() {
        let index = countControl.selectedSegment
        guard ReminderCount.allCases.indices.contains(index) else { return }
        settings.reminderCount = ReminderCount.allCases[index]
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
