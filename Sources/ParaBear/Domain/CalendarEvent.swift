import Foundation

struct CalendarEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarTitle: String

    var isHappeningNow: Bool {
        let now = Date()
        return startDate <= now && endDate > now
    }
}
