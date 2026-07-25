import SwiftUI

struct FloatingMotion: ViewModifier {
    let mood: BearMood
    let intensity: Double
    let startDate: Date

    func body(content: Content) -> some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            let multiplier = mood.motionMultiplier * intensity
            let sway = sin(elapsed * 0.62 * multiplier) * 18 * intensity
            let bob = sin(elapsed * 0.38 * multiplier) * 11 * intensity
            let rotation = sin(elapsed * 0.52 * multiplier) * 3.0

            content
                .offset(x: sway, y: bob)
                .rotationEffect(.degrees(rotation), anchor: .top)
        }
    }
}

extension View {
    func floatingMotion(mood: BearMood, intensity: Double, startDate: Date) -> some View {
        modifier(FloatingMotion(mood: mood, intensity: intensity, startDate: startDate))
    }
}
