import Foundation

/// The bear while the pointer is carrying the rig around — a weight on the end of a rope.
///
/// This is the one place the plain rule in `BearSwing` does not work, and it is worth being precise
/// about why, because the rule is right everywhere else.
///
/// `BearSwing` reads the swing off the motion happening *now*. That works when the motion is a
/// curve we wrote down, because there is always a well-defined speed and turnaround to read. A hand
/// is not a curve. It reports position in bursts, it reports nothing at all while it is holding
/// still, and it stops dead rather than easing through a turn. Reading a rule off that leaves the
/// bear frozen at whatever angle it last saw, which on screen looks like it has jammed. A rule also
/// cannot *accumulate* — and accumulation is the whole character of something on a rope: shake it
/// in rhythm and each shake adds to the last until it is swinging wildly.
///
/// So while it is held, the swing is integrated as a real pendulum:
///
/// - **The rope transmits acceleration, not speed.** Carrying a weight along at a steady pace
///   leaves it hanging; it is yanking and stopping that swings it. So the dominant drive is how the
///   hand is *accelerating*, and shaking harder therefore swings it harder with no extra rule.
/// - **Tuned to the rate a hand actually shakes at.** A pendulum only answers a drive near its own
///   frequency, so this one swings in about 0.84 s — right where a waggling hand lives.
/// - **Lightly damped, so shakes add up.** Q is about 3.6, meaning a rhythmic shake keeps building
///   for a few cycles before it tops out, then rings down over several more once the hand stops.
/// - **The restoring force is `sin` of the angle, not the angle.** A real pendulum gets *softer* as
///   it swings wider, so big swings go further and slow down at the top. Using the angle directly
///   would make it stiffen like a spring instead, and it would read as bouncy rather than roped.
///
/// A small trail from the hand's speed is kept on top, which is the air resistance on a light bear
/// being towed along — enough to lean it while it is carried steadily, not enough to dominate.
///
/// Positive degrees swings the bear's body to the left, matching a top-anchored rotation.
enum CarriedSwing {
    /// Natural frequency squared at small angles: omega = 7.5 rad/s, a 0.84 s swing.
    ///
    /// Short rope, and that choice is the difference between shaking doing something and shaking
    /// doing nothing. A pendulum only answers a shake near its own frequency; drive it much faster
    /// and the response falls off with the square of the ratio. A slow 1.75 s bear simply ignored
    /// a hand waggling it at 1-2 Hz. At 0.84 s the bear sits right in the range a hand shakes at,
    /// so the swing builds instead of being averaged away.
    static let stiffness: Double = 56.25
    /// 2 * zeta * omega with zeta ~= 0.14, so Q ~= 3.6: rhythmic shaking pumps it up over about
    /// three swings, and it rings down over several more. Raising this is what kills the build-up.
    static let damping: Double = 2.1
    /// Degrees of drive per (point/s) the hand is travelling. Modest — this is only the lean from
    /// towing a light bear through the air, and it must not drown out the shaking.
    static let speedDrive: Double = 0.6
    /// Degrees of drive per (point/s^2) the hand is accelerating. This is the one that matters:
    /// shake amplitude enters here squared by frequency, which is why a harder shake reads so much
    /// bigger without any rule saying it should.
    static let accelerationDrive: Double = 0.125
    /// Hard stop, kept below 90 so the restoring force is still pulling the bear back rather than
    /// over the top. A violent shake touches this; a normal one does not come near it.
    static let maxDegrees: Double = 70

    struct State: Equatable {
        var degrees: Double = 0
        var angularVelocity: Double = 0

        static let level = State()
    }

    static func advance(
        _ state: State,
        handVelocity: Double,
        handAcceleration: Double,
        dt: TimeInterval
    ) -> State {
        guard dt > 0 else { return state }

        let drive = speedDrive * handVelocity + accelerationDrive * handAcceleration
        let acceleration = drive
            - stiffness * restoring(state.degrees)
            - damping * state.angularVelocity

        var next = state
        next.angularVelocity += acceleration * dt
        next.degrees += next.angularVelocity * dt

        if next.degrees > maxDegrees {
            next.degrees = maxDegrees
            next.angularVelocity = min(0, next.angularVelocity)
        } else if next.degrees < -maxDegrees {
            next.degrees = -maxDegrees
            next.angularVelocity = max(0, next.angularVelocity)
        }

        return next
    }

    /// `sin` of the angle, expressed back in degrees so it matches the angle exactly while the
    /// swing is small and falls short of it — a weaker pull home — as the swing gets wide.
    static func restoring(_ degrees: Double) -> Double {
        (180 / .pi) * sin(degrees * .pi / 180)
    }
}
