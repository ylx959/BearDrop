import SwiftUI

struct TodayEventsPanel: View {
    let events: [CalendarEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Next Hour")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            if events.isEmpty {
                Text("No events in the next hour")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 8) {
                    ForEach(events.prefix(8)) { event in
                        eventRow(event)
                    }
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 10)
    }

    private func eventRow(_ event: CalendarEvent) -> some View {
        HStack(spacing: 10) {
            Text(EventTimelineViewModel.timeString(for: event.startDate))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .lineLimit(1)
                Text(event.calendarTitle)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if event.isHappeningNow {
                Text("Now")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.72, green: 0.22, blue: 0.18))
            }
        }
        .frame(height: 34)
    }
}
