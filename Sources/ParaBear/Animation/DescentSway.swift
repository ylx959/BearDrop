import Foundation

/// The window's side-to-side sweep as the bear comes down the screen.
///
/// Written out as a curve, exactly like `RigSway`, and for exactly the same reason: both of the
/// bear's rules need the speed and the turnaround of the motion the eye is watching, and a curve
/// hands those over exactly.
///
/// This replaced a pair of spring integrators — a broad sway chasing a moving target, and a wind
/// sway layered on top — and every problem the descent's swing had came from that arrangement
/// rather than from the rules:
///
/// - The springs' state was clamped at three separate points, and a clamped offset kept reporting
///   the velocity it had when it hit the wall, so the bear leant against travel that had stopped.
/// - Only the broad sway had strokes. The wind sway's acceleration was a wobble with no turnaround
///   in it, so folding it in fired the throw-onward at arbitrary moments mid-sweep.
/// - Sizing the lean meant guessing what the springs were about to do.
///
/// A curve has none of that. It cannot be clamped because the amplitude is chosen to fit the
/// corridor in the first place, its peak speed and turnaround are known in closed form, and the two
/// rules read the same expression the window's position comes from.
struct DescentSway: Equatable {
    /// The widest sweep worth making, as a share of the screen.
    static let sweepRatioOfScreen: Double = 0.42
    /// How much of the corridor a sweep may claim, leaving the rest as room to start off-centre.
    static let sweepShareOfCorridor: Double = 0.8
    /// The slow wander, as a share of the main stroke. Small and slow on purpose: it keeps
    /// consecutive strokes from landing in the same place without muddying where a stroke ends.
    static let wanderShare: Double = 0.32
    static let wanderCycleShare: Double = 0.36
    /// How many times a flight sweeps across and back.
    static let strokeCycles: ClosedRange<Double> = 2.0...2.8
    /// How much of the opening sweep is left by the end of the descent.
    ///
    /// A canopy swings hardest just after it catches air and settles as it comes down, and every
    /// recipe for animating something hanging says the same thing: multiply the swing by an
    /// exponential decay. Without it a flight is a uniform zigzag from top to bottom, with no
    /// arc to it — the bear arrives at the bottom of the screen swinging exactly as hard as it
    /// did at the top.
    static let settleShare: Double = 0.45
    /// Sets how fast the settling happens: by the end of the flight the decaying part is down to
    /// about a tenth, so the sweep spends most of the descent near `settleShare`.
    static let settleSharpness: Double = 2.3

    var strokeAmplitude: Double
    var strokeRate: Double
    var strokePhase: Double
    var wanderAmplitude: Double
    var wanderRate: Double
    var wanderPhase: Double
    /// How quickly the sweep settles, per second.
    var settleRate: Double = 0

    /// How far the curve can get from where it is centred. The caller places the flight so this
    /// much room exists on both sides, which is what makes clamping unnecessary.
    var reach: Double { strokeAmplitude + wanderAmplitude }

    /// What a normal stroke reaches *at this moment in the descent*, which is what `BearSwing`
    /// sizes the lean against. Taken from the main stroke alone, from this flight's own numbers,
    /// and settled by the same envelope as the sweep itself.
    ///
    /// Following the envelope matters. Left at the opening figure, the lean's size would depend on
    /// where the flight's random phase happened to put its first peak — early flights leaning a
    /// full 15 degrees, later-peaking ones only eleven — which is the flight-to-flight wobble this
    /// whole arrangement exists to avoid. Following it instead means every stroke is expressed in
    /// full: the *path* settles as the canopy comes down, and the bear keeps answering each stroke
    /// rather than going limp at the bottom of the screen.
    func nominalSpeed(at time: TimeInterval) -> Double {
        envelope(at: time).0 * strokeAmplitude * strokeRate
    }

    func nominalTurn(at time: TimeInterval) -> Double {
        envelope(at: time).0 * strokeAmplitude * strokeRate * strokeRate
    }

    /// The settling envelope the whole sweep is multiplied by, and its first two derivatives —
    /// which the product rule below needs, because velocity and acceleration have to be the true
    /// derivatives of the position actually drawn. An envelope applied to the position alone would
    /// quietly put the two rules out of step with the motion.
    private func envelope(at time: TimeInterval) -> (Double, Double, Double) {
        let decaying = (1 - Self.settleShare) * exp(-settleRate * max(0, time))

        return (
            Self.settleShare + decaying,
            -settleRate * decaying,
            settleRate * settleRate * decaying
        )
    }

    /// The sweep before it is settled: two sines, and their first two derivatives.
    private func stroke(at time: TimeInterval) -> (Double, Double, Double) {
        let a = strokeRate * time + strokePhase
        let b = wanderRate * time + wanderPhase

        return (
            strokeAmplitude * sin(a) + wanderAmplitude * sin(b),
            strokeAmplitude * strokeRate * cos(a) + wanderAmplitude * wanderRate * cos(b),
            -strokeAmplitude * strokeRate * strokeRate * sin(a)
                - wanderAmplitude * wanderRate * wanderRate * sin(b)
        )
    }

    func offset(at time: TimeInterval) -> Double {
        envelope(at: time).0 * stroke(at: time).0
    }

    func velocity(at time: TimeInterval) -> Double {
        let (e, de, _) = envelope(at: time)
        let (s, ds, _) = stroke(at: time)

        return de * s + e * ds
    }

    func acceleration(at time: TimeInterval) -> Double {
        let (e, de, dde) = envelope(at: time)
        let (s, ds, dds) = stroke(at: time)

        return dde * s + 2 * de * ds + e * dds
    }

    /// A fresh sweep. `room` is how far the window may travel either side of where the sweep will
    /// be centred; the sweep is sized to fit inside that with something to spare, which is what
    /// means nothing downstream ever has to hold it back.
    static func random(
        room: Double,
        screenWidth: Double,
        flightDuration: TimeInterval
    ) -> DescentSway {
        let usable = max(0, room) * sweepShareOfCorridor
        let stroke = min(screenWidth * sweepRatioOfScreen, usable / (1 + wanderShare))
        let cycles = Double.random(in: strokeCycles)
        let rate = 2 * .pi * cycles / max(flightDuration, 0.1)

        return DescentSway(
            strokeAmplitude: stroke,
            strokeRate: rate,
            strokePhase: Double.random(in: 0...(2 * .pi)),
            wanderAmplitude: stroke * wanderShare,
            wanderRate: rate * wanderCycleShare,
            wanderPhase: Double.random(in: 0...(2 * .pi)),
            settleRate: settleSharpness / max(flightDuration, 0.1)
        )
    }

    /// The same, but starting at zero offset, so a flight resumed from wherever the bear was put
    /// down begins exactly there instead of jumping to somewhere along a sweep already in progress.
    static func startingLevel(
        room: Double,
        screenWidth: Double,
        flightDuration: TimeInterval
    ) -> DescentSway {
        var sway = random(room: room, screenWidth: screenWidth, flightDuration: flightDuration)
        guard sway.strokeAmplitude > 0 else { return sway }

        // Whatever the wander happens to contribute at t = 0, start the stroke where it cancels.
        let wander = sway.wanderAmplitude * sin(sway.wanderPhase)
        sway.strokePhase = asin(max(-1, min(1, -wander / sway.strokeAmplitude)))

        return sway
    }
}
