import EventKit
import Foundation

@MainActor
final class CalendarService: ObservableObject {
    enum AuthorizationState: Equatable {
        case unknown
        case authorized
        case denied
    }

    @Published private(set) var authorizationState: AuthorizationState = .unknown
    @Published private(set) var todayEvents: [CalendarEvent] = []
    @Published private(set) var nextEvent: CalendarEvent?

    private let eventStore = EKEventStore()
    private let calendar = Calendar.autoupdatingCurrent

    func refresh() async {
        guard await ensureAuthorization() else {
            todayEvents = []
            nextEvent = nil
            return
        }

        let events = fetchUpcomingEvents()
        todayEvents = events
        nextEvent = events.first(where: { $0.endDate > Date() })
    }

    private func ensureAuthorization() async -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized:
            authorizationState = .authorized
            return true
        case .denied, .restricted, .writeOnly:
            authorizationState = .denied
            return false
        case .notDetermined:
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                authorizationState = granted ? .authorized : .denied
                return granted
            } catch {
                authorizationState = .denied
                return false
            }
        @unknown default:
            authorizationState = .denied
            return false
        }
    }

    private func fetchUpcomingEvents() -> [CalendarEvent] {
        let now = Date()
        let oneHourFromNow = calendar.date(byAdding: .hour, value: 1, to: now) ?? now.addingTimeInterval(60 * 60)
        let predicate = eventStore.predicateForEvents(withStart: now, end: oneHourFromNow, calendars: nil)

        return eventStore.events(matching: predicate)
            .filter { !$0.isAllDay }
            .filter { $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                CalendarEvent(
                    id: event.eventIdentifier ?? "\(event.calendarItemIdentifier)-\(event.startDate.timeIntervalSince1970)",
                    title: event.title?.isEmpty == false ? event.title : "Untitled Event",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    calendarTitle: event.calendar.title
                )
            }
    }
}
