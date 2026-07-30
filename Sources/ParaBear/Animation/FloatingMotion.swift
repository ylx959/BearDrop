import SwiftUI

/// One frame of the in-place sway.
struct WindSwayMotion: Equatable {
    let horizontalOffset: CGFloat
    let canopyHorizontalOffset: CGFloat
    let payloadHorizontalOffset: CGFloat
    let verticalBob: CGFloat
    let canopyRotationDegrees: Double
    let payloadRotationDegrees: Double

    var rotationDegrees: Double { payloadRotationDegrees }

    /// The whole pose is a plain function of elapsed time. Nothing is integrated and nothing is
    /// carried between frames, so the bear's swing is always exactly what the rig's current motion
    /// says it should be — see `BearSwing` for the two rules.
    static func sample(
        elapsed: TimeInterval,
        mood: BearMood,
        intensity: Double,
        windStyle: WindStyle = .windy,
        seed: Double = 0,
        alongside carriedTravel: BearSwing.Travel = .still
    ) -> WindSwayMotion {
        let clampedIntensity = max(0, intensity)
        let time = max(0, elapsed) * mood.motionMultiplier

        let offset = RigSway.offset(at: time, seed: seed)
        let velocity = RigSway.velocity(at: time, seed: seed)
        let acceleration = RigSway.acceleration(at: time, seed: seed)

        // The rules are applied once, to the drift drawn here *plus* whatever else is carrying the
        // bear along — see `BearSwing.Travel`.
        let swingDegrees = BearSwing.degrees(for: carriedTravel + BearSwing.Travel(
            velocity: velocity,
            acceleration: acceleration,
            nominalSpeed: RigSway.nominalSpeed,
            nominalTurn: RigSway.nominalTurn
        ))


        // The canopy gets rule 1 only, and gently: a big soft wing leans back against the air it is
        // being pulled through, but it has nothing hanging off it to throw onward at a turnaround.
        let lateral = CGFloat(offset * clampedIntensity * windStyle.lateralMultiplier)
        let rotationScale = clampedIntensity * windStyle.rotationMultiplier

        return WindSwayMotion(
            horizontalOffset: lateral,
            canopyHorizontalOffset: lateral,
            payloadHorizontalOffset: lateral,
            verticalBob: CGFloat(
                RigSway.bob(at: time, seed: seed)
                    * clampedIntensity * windStyle.verticalMultiplier
            ),
            canopyRotationDegrees: RigSway.canopyLean(velocity: velocity) * rotationScale,
            payloadRotationDegrees: swingDegrees * rotationScale
        )
    }
}

/// The rig's side-to-side drift, written out as a curve rather than simulated.
///
/// Two slow sines at unrelated periods: one long stroke that carries the rig from side to side, and
/// a slower wander that keeps consecutive strokes from landing in the same place. Because it is
/// written down rather than integrated, its speed and its turnaround are available exactly — which
/// is what `BearSwing` needs, and what stops the swing from ever lagging the drift.
enum RigSway {
    static let strokeAmplitude: Double = 11
    static let strokePeriod: Double = 9
    /// Kept slow and small on purpose. The wander exists only so consecutive strokes do not land
    /// in the same place; any faster and its own travel muddies the two rules at the moment the
    /// main stroke turns around, which is exactly where rule 2 is supposed to read cleanly.
    static let wanderAmplitude: Double = 3.5
    static let wanderPeriod: Double = 26

    /// Slow vertical float, so the rig still breathes when the drift is at an end of its stroke.
    static let bobAmplitude: Double = 3.4
    static let bobPeriod: Double = 12.5

    /// How far the canopy leans back against the travel. Small — the card and lines above the bear
    /// should read as steady while the bear does the swinging.
    static let canopyLeanDegrees: Double = 3.2

    static var strokeRate: Double { 2 * .pi / strokePeriod }
    static var wanderRate: Double { 2 * .pi / wanderPeriod }

    /// What a normal stroke reaches, used to size the swing. Taken from the main stroke alone, so
    /// the usual stroke gives the full stated lean and the occasional stroke that lines up with the
    /// wander simply tops out.
    static var nominalSpeed: Double { strokeAmplitude * strokeRate }
    static var nominalTurn: Double { strokeAmplitude * strokeRate * strokeRate }

    static func offset(at time: TimeInterval, seed: Double) -> Double {
        strokeAmplitude * sin(strokeRate * time + strokePhase(seed))
            + wanderAmplitude * sin(wanderRate * time + wanderPhase(seed))
    }

    static func velocity(at time: TimeInterval, seed: Double) -> Double {
        strokeAmplitude * strokeRate * cos(strokeRate * time + strokePhase(seed))
            + wanderAmplitude * wanderRate * cos(wanderRate * time + wanderPhase(seed))
    }

    static func acceleration(at time: TimeInterval, seed: Double) -> Double {
        -strokeAmplitude * strokeRate * strokeRate * sin(strokeRate * time + strokePhase(seed))
            - wanderAmplitude * wanderRate * wanderRate * sin(wanderRate * time + wanderPhase(seed))
    }

    static func bob(at time: TimeInterval, seed: Double) -> Double {
        bobAmplitude * sin(2 * .pi / bobPeriod * time + seed * 0.013)
    }

    /// Rule 1 only, scaled down: the canopy leans back against the travel and no more.
    static func canopyLean(velocity: Double) -> Double {
        guard nominalSpeed > 0 else { return 0 }

        return canopyLeanDegrees * tanh(2 * velocity / nominalSpeed) / tanh(2)
    }

    private static func strokePhase(_ seed: Double) -> Double { seed * 0.017 }
    private static func wanderPhase(_ seed: Double) -> Double { seed * 0.041 + 1.7 }
}

struct FloatingMotion: ViewModifier {
    let mood: BearMood
    let intensity: Double
    let windStyle: WindStyle
    let startDate: Date

    func body(content: Content) -> some View {
        TimelineView(.animation) { timeline in
            let motion = WindSwayMotion.sample(
                elapsed: timeline.date.timeIntervalSince(startDate),
                mood: mood,
                intensity: intensity,
                windStyle: windStyle,
                seed: startDate.timeIntervalSinceReferenceDate
            )

            content
                .offset(x: motion.horizontalOffset, y: motion.verticalBob)
                .rotationEffect(.degrees(motion.payloadRotationDegrees), anchor: .top)
        }
    }
}

extension View {
    func floatingMotion(
        mood: BearMood,
        intensity: Double,
        windStyle: WindStyle = .windy,
        startDate: Date
    ) -> some View {
        modifier(FloatingMotion(
            mood: mood,
            intensity: intensity,
            windStyle: windStyle,
            startDate: startDate
        ))
    }
}
