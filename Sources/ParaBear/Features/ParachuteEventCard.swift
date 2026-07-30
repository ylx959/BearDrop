import SwiftUI

struct ParachuteEventCard: View {
    let event: CalendarEvent?
    let countdownText: String
    let authorizationState: CalendarService.AuthorizationState
    let mood: BearMood
    var appearance: RigAppearance = .dark
    var onTap: () -> Void = {}

    /// The canopy is drawn at the crop's own proportions, so the hem lands exactly on the bottom
    /// edge of the card and the suspension lines start where the fabric ends.
    static let width: CGFloat = 244
    static var height: CGFloat { ParachuteCanopy.height(forWidth: width) }

    /// The text's colours come from the rig's own scheme, not from `.primary`/`.secondary`. The
    /// canopy is lit fabric and is never tinted by the system, so system colours would flip
    /// underneath it the moment macOS changed appearance and leave black on near-black.
    private var palette: CanopyPalette { CanopyPalette.of(appearance) }

    var body: some View {
        ZStack {
            ParachuteCanopyView(appearance: appearance)
                .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 10)

            VStack(spacing: 7) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(palette.title)

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(palette.subtitle)

                Text(countdownText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(accentColor)
            }
            .padding(.horizontal, 26)
            .frame(width: 218)
            .offset(y: -9)
            // The fabric is sheer enough that what is behind the window reaches the type. The
            // shadow is what keeps it legible over an unknown desktop without having to thicken
            // the canopy back up — and it is a *glow* on the light scheme, since there the thing
            // black type has to survive is a bright desktop coming through.
            .shadow(color: palette.textShadow, radius: palette.textShadowRadius, x: 0, y: 1)
        }
        .frame(width: Self.width, height: Self.height)
        .compositingGroup()
        // The canopy's own outline, not its bounding box: the corners either side of the dome are
        // desktop showing through, and a tap there belongs to whatever is behind the window.
        .contentShape(ParachuteCanopy())
        .onTapGesture(perform: onTap)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens Google Calendar")
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

    /// The alert and urgent tones differ sharply between the schemes: the deep orange and red that
    /// read as a warning on white fabric go muddy on near-black, and the lifted pair that work
    /// there wash out to pastel on white.
    private var accentColor: Color {
        switch mood {
        case .calm: palette.subtitle
        case .alert: palette.alert
        case .urgent: palette.urgent
        }
    }
}
