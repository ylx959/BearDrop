import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = SettingsStore()

    private var calendarService: CalendarService?
    private var timelineViewModel: EventTimelineViewModel?
    private var overlayWindowController: BearOverlayWindowController?
    private var menuBarController: MenuBarController?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // `.regular` rather than `.accessory`: ParaBear sits in the Dock. The two policies are not
        // a menu of independent switches — a Dock icon and an application menu at the top of the
        // screen arrive together, and there is no policy that gives one without the other.
        NSApp.setActivationPolicy(.regular)

        let calendarService = CalendarService()
        let timelineViewModel = EventTimelineViewModel(
            calendarService: calendarService,
            settings: settings
        )

        self.calendarService = calendarService
        self.timelineViewModel = timelineViewModel

        let driftState = BearDriftState()
        overlayWindowController = BearOverlayWindowController(
            rootView: BearOverlayView(
                viewModel: timelineViewModel,
                settings: settings,
                driftState: driftState
            ),
            driftState: driftState
        )

        menuBarController = MenuBarController(
            settings: settings,
            calendarService: calendarService,
            onCallBear: { [weak self] in
                guard let self else { return }
                self.overlayWindowController?.playReminderFlight(duration: self.settings.plannedFlightSpeed.flightDuration)
            },
            onHideBear: { [weak self] in self?.overlayWindowController?.hide() },
            onOpenSettings: {
                NSApp.activate(ignoringOtherApps: true)
                SettingsLink().openSettings()
            }
        )

        Task {
            await timelineViewModel.start()
        }

        timelineViewModel.reminderFlights
            .sink { [weak self] _ in
                guard let self else { return }
                self.overlayWindowController?.playReminderFlight(duration: self.settings.plannedFlightSpeed.flightDuration)
            }
            .store(in: &cancellables)
    }

    /// A click on the Dock icon.
    ///
    /// There is nothing for it to raise — the bear is a panel that comes and goes on its own, and
    /// the Settings window is not what anyone is reaching for. So the Dock icon opens the same menu
    /// the menu bar item does, which makes it the second door to one room rather than an icon that
    /// swallows the click. That is also the answer when the bar is full and macOS has hidden the
    /// status item: the Dock is then the only way in.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        guard !hasVisibleWindows else { return true }

        // Next turn, not now. `performClick` runs the menu's own event-tracking loop, and starting
        // one inside the activation callback holds up the activation that asked for it.
        Task { @MainActor [weak self] in self?.menuBarController?.openMenu() }
        return false
    }
}

private extension SettingsLink {
    @MainActor
    func openSettings() {
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}
