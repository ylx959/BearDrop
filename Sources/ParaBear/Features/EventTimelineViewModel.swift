import Combine
import Foundation

@MainActor
final class EventTimelineViewModel: ObservableObject {
    @Published private(set) var authorizationState: CalendarService.AuthorizationState = .unknown
    @Published private(set) var nextEvent: CalendarEvent?
    @Published private(set) var todayEvents: [CalendarEvent] = []
    @Published private(set) var countdownText = "Loading"
    @Published private(set) var mood: BearMood = .calm
    @Published var isExpanded = false
    let reminderFlights = PassthroughSubject<ReminderMilestone, Never>()

    private let calendarService: CalendarService
    private let settings: SettingsStore
    private var cancellables: Set<AnyCancellable> = []
    private var countdownTask: Task<Void, Never>?
    private var calendarPollingTask: Task<Void, Never>?
    private var firedReminderKeys: Set<String> = []

    init(calendarService: CalendarService, settings: SettingsStore) {
        self.calendarService = calendarService
        self.settings = settings

        calendarService.$authorizationState
            .assign(to: &$authorizationState)
        calendarService.$nextEvent
            .sink { [weak self] event in
                self?.nextEvent = event
                self?.recalculateCountdown()
            }
            .store(in: &cancellables)
        calendarService.$todayEvents
            .assign(to: &$todayEvents)
    }

    deinit {
        countdownTask?.cancel()
        calendarPollingTask?.cancel()
    }

    func start() async {
        await calendarService.refresh()
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(for: .seconds(5))
            }
        }
        calendarPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                await self?.calendarService.refresh()
            }
        }
    }

    func toggleExpanded() {
        isExpanded.toggle()
    }

    private func tick() async {
        recalculateCountdown()
        fireReminderIfNeeded()
    }

    private func recalculateCountdown() {
        guard authorizationState != .denied else {
            countdownText = "Calendar access needed"
            mood = .calm
            return
        }

        guard let nextEvent else {
            countdownText = "Today is quiet"
            mood = .calm
            return
        }

        let seconds = nextEvent.startDate.timeIntervalSince(Date())
        if nextEvent.isHappeningNow {
            countdownText = "Happening now"
            mood = .urgent
            return
        }

        if seconds <= 0 {
            countdownText = "Starting now"
            mood = .urgent
            return
        }

        countdownText = Self.relativeCountdown(seconds: seconds)
        if seconds <= settings.urgentThresholdMinutes * 60 {
            mood = .urgent
        } else if seconds <= settings.alertThresholdMinutes * 60 {
            mood = .alert
        } else {
            mood = .calm
        }
    }

    private func fireReminderIfNeeded() {
        guard settings.isBearVisible else { return }
        guard let nextEvent else { return }

        let seconds = nextEvent.startDate.timeIntervalSince(Date())
        guard let milestone = ReminderMilestone.dueMilestone(for: seconds) else { return }

        let key = reminderKey(for: nextEvent, milestone: milestone)
        guard !firedReminderKeys.contains(key) else { return }

        for handledMilestone in ReminderMilestone.milestonesHandled(by: milestone) {
            firedReminderKeys.insert(reminderKey(for: nextEvent, milestone: handledMilestone))
        }
        reminderFlights.send(milestone)
    }

    private func reminderKey(for event: CalendarEvent, milestone: ReminderMilestone) -> String {
        "\(event.id)-\(Int(event.startDate.timeIntervalSince1970))-\(milestone)"
    }

    static func timeString(for date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private static func relativeCountdown(seconds: TimeInterval) -> String {
        let totalMinutes = max(1, Int(ceil(seconds / 60)))
        if totalMinutes < 60 {
            return "in \(totalMinutes) min"
        }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if minutes == 0 {
            return "in \(hours) hr"
        }
        return "in \(hours) hr \(minutes) min"
    }
}
