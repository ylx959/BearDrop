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
    /// What the bear is saying right now. Chosen when the bubble opens and then held — see
    /// `BearRemark`.
    @Published private(set) var remark = BearRemark.all[0]
    let reminderFlights = PassthroughSubject<ReminderMilestone, Never>()

    private let calendarService: CalendarService
    private let settings: SettingsStore
    private var cancellables: Set<AnyCancellable> = []
    private var countdownTask: Task<Void, Never>?
    private var calendarPollingTask: Task<Void, Never>?
    private var firedReminderKeys: Set<String> = []
    /// Events the bear is done with — see `ReminderSchedule.underwayDelay`. They stay in
    /// `todayEvents`, they are simply never chosen again.
    private var finishedEventKeys: Set<String> = []

    init(calendarService: CalendarService, settings: SettingsStore) {
        self.calendarService = calendarService
        self.settings = settings

        calendarService.$authorizationState
            .assign(to: &$authorizationState)
        // Which event the bear is on is decided here rather than by the service, because the rule
        // has state the service does not have: an event is dropped once the bear has finished with
        // it, and that happens on the five-second tick — twelve times more often than the calendar
        // is polled. Deciding it in the service would leave the poll racing the tick for the last
        // milestone, and the poll would sometimes win by retiring the event before it fired.
        calendarService.$todayEvents
            .sink { [weak self] events in
                self?.todayEvents = events
                self?.selectNextEvent()
                self?.recalculateCountdown()
            }
            .store(in: &cancellables)
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

    /// Re-reads the calendar and settles the answer *now*, for "Call ParaBear".
    ///
    /// The poll runs once a minute, so what the view model holds can be up to a minute old — long
    /// enough for the whole next-hour window to have changed, and a call is a question about that
    /// window rather than a request to repeat the last poll's answer. Retirement is deliberately
    /// left alone: an event the bear has already handed over stays handed over, so calling it back
    /// cannot resurrect a meeting that is done with.
    func refreshNow() async {
        await calendarService.refresh()
        selectNextEvent()
        recalculateCountdown()
    }

    /// Pins the remark, so `GreetingSnapshot` can render the longest one — the case the bubble's
    /// width is chosen on — rather than whichever line the shuffle happened to land on.
    func showRemarkForSnapshot(_ remark: String) {
        self.remark = remark
    }

    func toggleExpanded() {
        isExpanded.toggle()

        if isExpanded {
            remark = BearRemark.next(after: remark)
        }
    }

    private func tick() async {
        selectNextEvent()
        recalculateCountdown()
        fireReminderIfNeeded()
    }

    /// The first event still worth showing: not already over, and not one the bear has finished
    /// with. Re-checked every tick rather than only when the calendar is polled, because both of
    /// those go stale between polls.
    private func selectNextEvent() {
        nextEvent = Self.nextEvent(from: todayEvents, finished: finishedEventKeys, now: Date())
    }

    /// Stated as a function of its inputs so the rule can be checked directly — the interesting
    /// case, an in-progress event standing in front of the ones behind it, takes half an hour to
    /// reach in real time.
    static func nextEvent(
        from events: [CalendarEvent],
        finished: Set<String>,
        now: Date
    ) -> CalendarEvent? {
        events.first { $0.endDate > now && !finished.contains(eventKey(for: $0)) }
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

        // Read fresh every tick rather than held, because the menu can change it between two of
        // them. Doing so is safe in both directions and neither needs special handling: a due
        // milestone is only ever the latest one already *passed*, so lengthening the lead cannot
        // retrospectively fire the flights the longer schedule would have made, and shortening it
        // cannot replay one, because the key is the offset and the offsets that survive the change
        // keep theirs.
        let schedule = settings.reminderSchedule
        let seconds = nextEvent.startDate.timeIntervalSince(Date())
        guard let milestone = schedule.dueMilestone(for: seconds) else { return }

        let key = reminderKey(for: nextEvent, milestone: milestone)
        guard !firedReminderKeys.contains(key) else { return }

        for handledMilestone in schedule.milestonesHandled(by: milestone) {
            firedReminderKeys.insert(reminderKey(for: nextEvent, milestone: handledMilestone))
        }

        // The last milestone retires the event, and it does so *before* the flight goes out rather
        // than after. Dropping it here is what lets whatever is behind it start its own countdown —
        // an event left in place until its end time blocks the ones after it, and back-to-back
        // meetings then get no warning at all. Doing it first also settles what the flight will
        // say: the card reads this view model live, so a flight launched before the handover shows
        // the retired event for a frame and then switches under itself.
        if milestone.isLast {
            finishedEventKeys.insert(Self.eventKey(for: nextEvent))
            selectNextEvent()
            recalculateCountdown()
        }

        guard Self.isWorthFlying(milestone, handingOverTo: self.nextEvent) else { return }

        reminderFlights.send(milestone)
    }

    /// The last milestone's flight is a handover — *that one is done, here is the next*. With
    /// nothing behind it there is nothing to hand over to, and the bear would be parachuting in
    /// only to report that there is nothing to report. The other milestones always have their own
    /// event to announce.
    static func isWorthFlying(
        _ milestone: ReminderMilestone,
        handingOverTo next: CalendarEvent?
    ) -> Bool {
        !milestone.isLast || next != nil
    }

    /// Identifies an occurrence, not a series: a repeating event carries the same id for every one
    /// of its starts, and finishing with this morning's stand-up must not silence tomorrow's.
    static func eventKey(for event: CalendarEvent) -> String {
        "\(event.id)-\(Int(event.startDate.timeIntervalSince1970))"
    }

    /// Names the occurrence and the point on its approach. The point is the milestone's *offset*
    /// rather than the whole value, so that a milestone at the same moment is the same reminder
    /// whatever schedule produced it — which is what lets the settings change mid-event.
    private func reminderKey(for event: CalendarEvent, milestone: ReminderMilestone) -> String {
        "\(Self.eventKey(for: event))-\(Int(milestone.offsetFromStart))"
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
