import Foundation
import Testing
@testable import ParaBear

struct DescentSwayTests {
    private static let room = 574.0
    private static let screenWidth = 1_440.0
    private static let duration = PlannedFlightSpeed.fast.flightDuration

    private static func sway(room: Double = room) -> DescentSway {
        DescentSway.random(room: room, screenWidth: screenWidth, flightDuration: duration)
    }

    /// The whole reason this is a curve: it is sized to fit, so nothing ever has to hold it back.
    /// A held-back sweep is what left the bear leaning against travel that had already stopped.
    @Test func aSweepAlwaysFitsInTheRoomItWasGiven() {
        for room in [40.0, 200, 574, 2_000] {
            let sway = Self.sway(room: room)

            #expect(sway.reach <= room + 0.001)
            for step in 0...2_000 {
                #expect(abs(sway.offset(at: Double(step) / 20)) <= room + 0.001)
            }
        }
    }

    /// Velocity and acceleration have to be the real derivatives of the drawn position, or the two
    /// rules are describing something other than what is on screen.
    @Test func speedAndTurnaroundMatchThePositionTheyComeFrom() {
        let sway = Self.sway()
        let step = 1e-5

        // From just after the start: the settling envelope is held flat before t = 0 so a flight
        // read slightly behind itself cannot be handed a sweep wider than the room it was given,
        // and that leaves a kink at exactly zero which a central difference cannot straddle.
        for frame in 1...200 {
            let time = Double(frame) / 10
            let measuredSpeed = (sway.offset(at: time + step) - sway.offset(at: time - step)) / (2 * step)
            let measuredTurn = (sway.velocity(at: time + step) - sway.velocity(at: time - step)) / (2 * step)

            #expect(abs(measuredSpeed - sway.velocity(at: time)) < 0.01)
            #expect(abs(measuredTurn - sway.acceleration(at: time)) < 0.01)
        }
    }

    /// The lean is scaled by this, so it has to be the sweep's own peak — not a guess. Sizing it
    /// against anything else is what made the same visible sweep lean differently flight to flight.
    @Test func theNominalTracksTheSweepAtEveryMoment() {
        let sway = Self.sway()

        for step in 0...4_000 {
            let time = Double(step) / 40
            // The wander adds a little on top of the main stroke, and no more than a little — at
            // every point in the descent, not just at the start.
            #expect(abs(sway.velocity(at: time)) < sway.nominalSpeed(at: time) * 1.35)
            #expect(abs(sway.acceleration(at: time)) < sway.nominalTurn(at: time) * 1.35)
        }

        // And it settles with the sweep rather than staying at the opening figure.
        #expect(sway.nominalSpeed(at: Self.duration) < sway.nominalSpeed(at: 0) * 0.7)
    }

    /// Which means `BearSwing` is fed values that stay inside the range its response curve is
    /// honest over — the condition that broke when the descent guessed at its own scale.
    @Test func theSwingNeverRunsPastWhatItsCurveCanExpress() {
        let sway = Self.sway()

        for step in 0...4_000 {
            let time = Double(step) / 40
            let lean = BearSwing.degrees(
                velocity: sway.velocity(at: time),
                acceleration: sway.acceleration(at: time),
                nominalSpeed: sway.nominalSpeed(at: time),
                nominalTurn: sway.nominalTurn(at: time)
            )

            #expect(abs(lean) <= (BearSwing.trailDegrees + BearSwing.turnDegrees) * 1.05)
        }
    }

    /// Every stroke, on every flight: leaning the other way while travelling, thrown onward at the
    /// end. This is the pair of rules, checked on the descent rather than on the in-place drift.
    @Test func bothRulesHoldOnEveryStrokeOfEveryFlight() {
        for _ in 0..<50 {
            let sway = Self.sway()
            let quarter = (.pi / 2) / sway.strokeRate

            for stroke in 0..<4 {
                let midStroke = Double(stroke) * 2 * quarter - sway.strokePhase / sway.strokeRate
                guard midStroke > 0 else { continue }

                let strokeEnd = midStroke + quarter
                let lean = { (time: Double) in
                    BearSwing.degrees(
                        velocity: sway.velocity(at: time),
                        acceleration: sway.acceleration(at: time),
                        nominalSpeed: sway.nominalSpeed(at: time),
                        nominalTurn: sway.nominalTurn(at: time)
                    )
                }

                // Rule 1, mid-stroke: leaning against the way it is going.
                #expect(lean(midStroke).sign == sway.velocity(at: midStroke).sign)
                // Rule 2, at the end: thrown onward, to the side away from where it has arrived.
                #expect(lean(strokeEnd).sign != sway.offset(at: strokeEnd).sign)
            }
        }
    }

    /// A drop right against the edge of the corridor gets a sweep sized to the room left there,
    /// not to the whole corridor — otherwise it sweeps the card straight off the screen.
    @Test func aFlightResumedAtTheEdgeGetsASweepThatFitsThere() {
        let cramped = DescentSway.startingLevel(
            room: 30,
            screenWidth: Self.screenWidth,
            flightDuration: Self.duration
        )

        #expect(cramped.reach <= 30.001)
        #expect(abs(cramped.offset(at: 0)) < 0.001)
    }

    // MARK: - Settling

    /// A canopy swings hardest just after it catches air and settles on the way down. Without this
    /// the descent is a uniform zigzag with no arc to it.
    @Test func theSweepSettlesAsTheFlightGoesOn() {
        // Averaged over an ensemble of flights. A single flight is not a fair measurement: the
        // slow wander's phase moves the width of either window by more than the settling does.
        let spread = { (from: Double, to: Double) -> Double in
            (0..<20).map { _ -> Double in
                let sway = Self.sway()
                let samples = (0...500)
                    .map { sway.offset(at: from + (to - from) * Double($0) / 500) }
                return (samples.map { $0 * $0 }.reduce(0, +) / Double(samples.count)).squareRoot()
            }.reduce(0, +) / 20
        }
        let early = spread(0, Self.duration / 2)
        let late = spread(Self.duration / 2, Self.duration)

        #expect(late < early * 0.85)
        // But it settles to a drift, not to a dead stop.
        #expect(late > early * 0.4)
    }

    /// The envelope multiplies the position, so it has to multiply into the derivatives too — the
    /// rules read those, and an envelope applied to the position alone puts them out of step with
    /// the motion on screen.
    @Test func settlingIsCarriedIntoSpeedAndTurnaroundToo() {
        let sway = Self.sway()
        let step = 1e-5

        for frame in 1...200 {
            let time = Double(frame) / 10
            let measured = (sway.offset(at: time + step) - sway.offset(at: time - step)) / (2 * step)

            #expect(abs(measured - sway.velocity(at: time)) < 0.01)
        }
    }
}
