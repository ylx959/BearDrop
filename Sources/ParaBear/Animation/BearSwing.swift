import Foundation

/// How far the bear swings under the canopy, in degrees.
///
/// Two rules, and nothing else. There is no simulation here — no mass, no spring, no state carried
/// between frames. The pose is read straight off how the rig is moving right now, so it can never
/// drift out of step with what is on screen.
///
/// 1. **Travelling leans it the other way.** Sliding left leans the bear right by
///    `trailDegrees`; sliding right leans it left by the same.
/// 2. **Each end of the stroke throws it onward.** Arriving at the far left, the rig turns around
///    but the bear keeps going, so it swings left by `turnDegrees`. Same at the far right, the
///    other way.
///
/// Both rules come off the same motion. The first is the travel direction. The second is the
/// turnaround — slowing to a stop at the left end *is* an acceleration to the right, and it is
/// largest exactly at the end of the stroke, which is where the swing is wanted.
///
/// Every horizontal path the bear takes goes through here on the same terms — the in-place drift
/// (`RigSway`) and the descent sweep (`DescentSway`) — so a stroke of a given size leans the bear by
/// the same amount whichever of them is producing it.
///
/// Positive degrees swings the bear's body to the left, matching a top-anchored rotation.
enum BearSwing {
    /// Lean while the rig travels at its nominal speed. Rule 1.
    static let trailDegrees: Double = 18
    /// Swing at each end of a stroke, where the rig turns around. Rule 2.
    ///
    /// Deliberately the smaller of the two, and the reason is worth keeping. The two rules are 90
    /// degrees out of phase, so their ratio decides where the lean peaks — and a peak is a
    /// stationary point. Weighting the turn heavily puts the peak on the turnaround, which means
    /// the lean stops moving at the exact instant the rig changes direction: measured, a pure
    /// turn-only swing changes sixty times more slowly there than a trail-only one. Whatever it
    /// gains in pendulum accuracy it loses in the one moment the motion most needs to read.
    static let turnDegrees: Double = 6

    /// One horizontal path the bear is being taken along: how fast, how hard it is turning, and
    /// what a normal stroke of it reaches.
    ///
    /// The bear has one lean, so the rules are applied once, to everything moving it at once —
    /// which is what `+` is for. Running them separately on each path and adding the *angles*
    /// doubles the answer: the bear was leaning up to 48 degrees during a descent, because the
    /// window's sweep and the drift inside the window each got a full-sized lean of their own.
    struct Travel: Equatable {
        var velocity: Double = 0
        var acceleration: Double = 0
        var nominalSpeed: Double = 0
        var nominalTurn: Double = 0

        static let still = Travel()

        static func + (lhs: Travel, rhs: Travel) -> Travel {
            Travel(
                velocity: lhs.velocity + rhs.velocity,
                acceleration: lhs.acceleration + rhs.acceleration,
                nominalSpeed: lhs.nominalSpeed + rhs.nominalSpeed,
                nominalTurn: lhs.nominalTurn + rhs.nominalTurn
            )
        }
    }

    /// A normal stroke gives exactly `trailDegrees` mid-way and `turnDegrees` at its ends.
    static func degrees(for travel: Travel) -> Double {
        trailDegrees * unit(travel.velocity, nominal: travel.nominalSpeed)
            + turnDegrees * unit(travel.acceleration, nominal: travel.nominalTurn)
    }

    static func degrees(
        velocity: Double,
        acceleration: Double,
        nominalSpeed: Double,
        nominalTurn: Double
    ) -> Double {
        degrees(for: Travel(
            velocity: velocity,
            acceleration: acceleration,
            nominalSpeed: nominalSpeed,
            nominalTurn: nominalTurn
        ))
    }

    /// Maps a value against what a normal stroke reaches: nominal comes out as exactly 1, and it
    /// flattens just past that rather than running away, so an unusually hard stroke reads as "as
    /// far as it goes" instead of tipping the bear over.
    ///
    /// The tight ceiling is safe because both callers hand over a `nominal` taken from the very
    /// curve they are describing — `RigSway` and `DescentSway` each report their own peak — so the
    /// input only ever creeps a little past 1. It stops being safe the moment a caller sizes the
    /// lean against something other than the motion it is reading, which is worth remembering: an
    /// earlier version guessed at the descent's scale, overshot nominal for most of a flight, and
    /// the lean sat pinned while the window swept about underneath it.
    static func unit(_ value: Double, nominal: Double) -> Double {
        guard nominal > 0 else { return 0 }

        return tanh(2 * value / nominal) / tanh(2)
    }
}
