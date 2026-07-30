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
        NSApp.setActivationPolicy(.accessory)

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
