import SwiftUI

struct BearOverlayView: View {
    @ObservedObject var viewModel: EventTimelineViewModel
    @ObservedObject var settings: SettingsStore

    private let animationStart = Date()

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                ParachuteEventCard(
                    event: viewModel.nextEvent,
                    countdownText: viewModel.countdownText,
                    authorizationState: viewModel.authorizationState,
                    mood: viewModel.mood
                )
                .padding(.top, 18)

                riggingLines
                    .stroke(.secondary.opacity(0.32), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                    .frame(width: 170, height: 72)

                BearCharacterView(mood: viewModel.mood)
                    .frame(width: 124, height: 118)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                            viewModel.toggleExpanded()
                        }
                    }
            }
            .floatingMotion(
                mood: viewModel.mood,
                intensity: settings.animationIntensity,
                startDate: animationStart
            )

            if viewModel.isExpanded {
                TodayEventsPanel(events: viewModel.todayEvents)
                    .frame(width: 316)
                    .offset(y: 278)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            }
        }
        .frame(width: 340, height: 460, alignment: .top)
    }

    private var riggingLines: Path {
        Path { path in
            path.move(to: CGPoint(x: 16, y: 0))
            path.addLine(to: CGPoint(x: 72, y: 72))
            path.move(to: CGPoint(x: 85, y: 0))
            path.addLine(to: CGPoint(x: 85, y: 72))
            path.move(to: CGPoint(x: 154, y: 0))
            path.addLine(to: CGPoint(x: 98, y: 72))
        }
    }
}
