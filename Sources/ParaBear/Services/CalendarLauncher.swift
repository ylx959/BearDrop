import AppKit

/// Hands the user off to Google Calendar in the browser, at the day of the event the canopy is
/// currently showing.
///
/// `…/r/day/y/m/d` is Google Calendar's own deep link and takes the date in the user's own calendar
/// terms, so the components are read in the local time zone rather than formatted from UTC — an
/// event late in the evening otherwise lands on the following day. `u/0` is the first signed-in
/// account, which is what a signed-out or single-account browser resolves to anyway.
///
/// Note this leaves Apple's Calendar out of it entirely, including the EventKit events the card is
/// showing: a Google account synced into Calendar.app will line up, anything local to the Mac will
/// not be there.
enum CalendarLauncher {
    static func open(_ event: CalendarEvent?) {
        let day = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: event?.startDate ?? Date()
        )

        guard
            let year = day.year, let month = day.month, let date = day.day,
            let url = URL(string: "https://calendar.google.com/calendar/u/0/r/day/\(year)/\(month)/\(date)")
        else { return }

        NSWorkspace.shared.open(url)
    }
}
