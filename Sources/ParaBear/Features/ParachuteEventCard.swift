import SwiftUI

struct ParachuteEventCard: View {
    let event: CalendarEvent?
    let countdownText: String
    let authorizationState: CalendarService.AuthorizationState
    let mood: BearMood

    var body: some View {
        VStack(spacing: 7) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Text(countdownText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(accentColor)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .frame(width: 212)
        .frame(minHeight: 92)
        .background(.ultraThinMaterial, in: parachuteShape)
        .overlay {
            parachuteShape
                .strokeBorder(.white.opacity(0.38), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.13), radius: 18, x: 0, y: 10)
    }

    private var parachuteShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 52,
            bottomLeadingRadius: 18,
            bottomTrailingRadius: 18,
            topTrailingRadius: 52,
            style: .continuous
        )
    }

    private var title: String {
        if authorizationState == .denied {
            return "Calendar Permission"
        }
        return event?.title ?? "ParaBear"
    }

    private var subtitle: String {
        if authorizationState == .denied {
            return "Allow access in Settings"
        }
        guard let event else {
            return "No more events today"
        }
        return EventTimelineViewModel.timeString(for: event.startDate)
    }

    private var accentColor: Color {
        switch mood {
        case .calm: .secondary
        case .alert: Color(red: 0.76, green: 0.44, blue: 0.28)
        case .urgent: Color(red: 0.72, green: 0.22, blue: 0.18)
        }
    }
}
