import Foundation
import Testing
@testable import ParaBear

/// Both of the horizontal paths the bear takes go through `BearSwing` on the same terms, so both
/// have to obey the same four properties. These are measured on the curves themselves rather than
/// on an idealised sine, because each carries a slow wander on top of its main stroke — and the
/// descent a settling envelope as well — and it is the combination that has to hold up.
struct BearSwingTrajectoryTests {
    /// One sampled path: where it is, and how far the bear leans, moment by moment.
    private struct Path {
        let name: String
        let dt: Double
        let offset: [Double]
        let velocity: [Double]
        let lean: [Double]
    }

    private static func inPlace(seed: Double) -> Path {
        let dt = 1.0 / 120
        let times = (0..<Int(120 * 120)).map { Double($0) * dt }

        return Path(
            name: "in-place drift",
            dt: dt,
            offset: times.map { RigSway.offset(at: $0, seed: seed) },
            velocity: times.map { RigSway.velocity(at: $0, seed: seed) },
            lean: times.map {
                BearSwing.degrees(
                    velocity: RigSway.velocity(at: $0, seed: seed),
                    acceleration: RigSway.acceleration(at: $0, seed: seed),
                    nominalSpeed: RigSway.nominalSpeed,
                    nominalTurn: RigSway.nominalTurn
                )
            }
        )
    }

    private static func descent() -> Path {
        let duration = PlannedFlightSpeed.slow.flightDuration
        let sway = DescentSway.random(room: 574, screenWidth: 1_440, flightDuration: duration)
        let dt = 1.0 / 120
        let times = (0..<Int(duration / dt)).map { Double($0) * dt }

        return Path(
            name: "descent sweep",
            dt: dt,
            offset: times.map { sway.offset(at: $0) },
            velocity: times.map { sway.velocity(at: $0) },
            lean: times.map {
                BearSwing.degrees(
                    velocity: sway.velocity(at: $0),
                    acceleration: sway.acceleration(at: $0),
                    nominalSpeed: sway.nominalSpeed(at: $0),
                    nominalTurn: sway.nominalTurn(at: $0)
                )
            }
        )
    }

    private static func paths() -> [Path] {
        (0..<20).map { inPlace(seed: Double($0) * 137) } + (0..<20).map { _ in descent() }
    }

    /// Indices where the path turns around, and the fastest moment between each pair.
    private static func strokes(in path: Path) -> [(turn: Int, midStroke: Int, end: Int)] {
        let turns = (1..<path.velocity.count)
            .filter { (path.velocity[$0] > 0) != (path.velocity[$0 - 1] > 0) }
        guard turns.count > 2 else { return [] }

        return zip(turns, turns.dropFirst()).map { start, end in
            let fastest = (start..<end).max { abs(path.velocity[$0]) < abs(path.velocity[$1]) }!
            return (start, fastest, end)
        }
    }

    // MARK: - The rules

    @Test func everyTrajectoryLeansAgainstTheWayItIsTravelling() {
        for path in Self.paths() {
            for stroke in Self.strokes(in: path) {
                #expect(
                    path.lean[stroke.midStroke].sign == path.velocity[stroke.midStroke].sign,
                    "\(path.name): rule 1 broken mid-stroke"
                )
            }
        }
    }

    @Test func everyTrajectoryThrowsTheBearOnwardAtEveryTurnaround() {
        for path in Self.paths() {
            for stroke in Self.strokes(in: path) {
                #expect(
                    path.lean[stroke.turn].sign != path.offset[stroke.turn].sign,
                    "\(path.name): rule 2 broken at a turnaround"
                )
            }
        }
    }

    // MARK: - Where the lean peaks, and why it matters

    /// The lean must peak nearer the middle of a stroke than its ends. A peak is a stationary
    /// point, so a peak sitting on the turnaround would leave the lean motionless at the exact
    /// instant the rig changes direction — the thing that reads as the swing having stopped
    /// listening. This is what `trailDegrees` being the larger of the two buys.
    @Test func everyTrajectoryPeaksNearerMidStrokeThanTheTurnaround() {
        for path in Self.paths() {
            for stroke in Self.strokes(in: path) {
                let span = stroke.end - stroke.turn
                guard span > 20 else { continue }

                let peak = (stroke.turn..<stroke.end)
                    .max { abs(path.lean[$0]) < abs(path.lean[$1]) }!
                let position = Double(peak - stroke.turn) / Double(span)

                // Half a stroke runs turn -> mid -> turn, so mid-stroke is at 0.5.
                #expect(position > 0.25, "\(path.name): lean peaks too close to a turnaround")
                #expect(position < 0.75, "\(path.name): lean peaks too close to a turnaround")
            }
        }
    }

    /// And the consequence, stated directly: at the moment the direction changes, the lean has to
    /// be visibly moving.
    @Test func theLeanIsMovingBrisklyThroughEveryDirectionChange() {
        for path in Self.paths() {
            for stroke in Self.strokes(in: path) {
                let span = stroke.end - stroke.turn
                guard span > 20, stroke.turn - span / 10 > 0 else { continue }

                let window = span / 10
                let before = path.lean[stroke.turn - window]
                let after = path.lean[min(stroke.turn + window, path.lean.count - 1)]

                // A fifth of a stroke straddling the turn must move the bear a real amount.
                #expect(abs(after - before) > 3, "\(path.name): lean stalls through a reversal")
            }
        }
    }

    // MARK: - One bear, one lean

    /// The bear is moved by two things at once during a descent: the window's sweep, and the drift
    /// drawn inside the window. Running the rules on each and adding the *angles* doubles the
    /// answer — it had the bear leaning up to 48 degrees. Applied once to the combined travel, the
    /// stated ceiling holds.
    @Test func combiningTravelKeepsTheLeanWithinTheStatedAngles() {
        let sway = DescentSway.random(
            room: 574,
            screenWidth: 1_440,
            flightDuration: PlannedFlightSpeed.fast.flightDuration
        )
        let ceiling = (BearSwing.trailDegrees + BearSwing.turnDegrees) * 1.05
        var separatelyExceeded = false

        for step in 0...4_000 {
            let time = Double(step) / 200
            let descent = BearSwing.Travel(
                velocity: sway.velocity(at: time),
                acceleration: sway.acceleration(at: time),
                nominalSpeed: sway.nominalSpeed(at: time),
                nominalTurn: sway.nominalTurn(at: time)
            )
            let drift = BearSwing.Travel(
                velocity: RigSway.velocity(at: time, seed: 42),
                acceleration: RigSway.acceleration(at: time, seed: 42),
                nominalSpeed: RigSway.nominalSpeed,
                nominalTurn: RigSway.nominalTurn
            )

            #expect(abs(BearSwing.degrees(for: descent + drift)) <= ceiling)

            let added = BearSwing.degrees(for: descent) + BearSwing.degrees(for: drift)
            if abs(added) > ceiling { separatelyExceeded = true }
        }

        // And the old way really did blow past it, so this is guarding something real.
        #expect(separatelyExceeded)
    }

    /// Combining is a sum, so a path that is not moving contributes nothing and cannot dilute one
    /// that is.
    @Test func stillTravelChangesNothing() {
        let travel = BearSwing.Travel(
            velocity: 120, acceleration: 40, nominalSpeed: 200, nominalTurn: 60
        )

        #expect(BearSwing.degrees(for: travel + .still) == BearSwing.degrees(for: travel))
    }
}
