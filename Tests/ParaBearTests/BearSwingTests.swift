import Foundation
import Testing
@testable import ParaBear

struct BearSwingTests {
    private static let nominalSpeed = 325.0
    private static let nominalTurn = 272.0

    private static func lean(velocity: Double, acceleration: Double = 0) -> Double {
        BearSwing.degrees(
            velocity: velocity,
            acceleration: acceleration,
            nominalSpeed: nominalSpeed,
            nominalTurn: nominalTurn
        )
    }

    /// A normal stroke still means exactly what it says.
    @Test func aNominalStrokeGivesTheStatedAngles() {
        #expect(abs(Self.lean(velocity: Self.nominalSpeed) - BearSwing.trailDegrees) < 0.001)
        #expect(
            abs(Self.lean(velocity: 0, acceleration: Self.nominalTurn) - BearSwing.turnDegrees)
                < 0.001
        )
    }

    @Test func theResponseIsMonotoneAndOdd() {
        var previous = -Double.infinity

        for step in 0...200 {
            let fraction = Double(step) / 100
            let value = fraction * Self.nominalSpeed
            let response = BearSwing.unit(value, nominal: Self.nominalSpeed)

            #expect(response >= previous)
            // Strictly rising over the range a stroke actually uses; flat beyond it is the point.
            if fraction <= 1 { #expect(response > previous) }
            #expect(abs(response + BearSwing.unit(-value, nominal: Self.nominalSpeed)) < 1e-12)
            previous = response
        }
    }

    @Test func theResponseStillTopsOutRatherThanRunningAway() {
        let absurd = Self.lean(velocity: Self.nominalSpeed * 50, acceleration: Self.nominalTurn * 50)

        #expect(abs(absurd) < (BearSwing.trailDegrees + BearSwing.turnDegrees) * 1.1)
    }

    /// The symptom as it was reported: the window changes direction and the bear does not move.
    ///
    /// Sweeping the whole stroke, the lean has to keep changing frame by frame — a run of frames
    /// where it barely moves means both terms are pinned again. The overshoot here is deliberate:
    /// on a descent the broad sweep and the wind sway add up and exceed nominal, which is exactly
    /// the case that used to clip.
    @Test func theLeanKeepsMovingAllTheWayRoundAStroke() {
        let overshoot = 1.1
        let samples = (0..<360).map { degree -> Double in
            let phase = Double(degree) * .pi / 180
            return Self.lean(
                velocity: Self.nominalSpeed * overshoot * sin(phase),
                acceleration: Self.nominalTurn * overshoot * cos(phase)
            )
        }
        let steps = zip(samples, samples.dropFirst()).map { abs($1 - $0) }
        var longestStall = 0
        var stall = 0
        for step in steps {
            stall = step < 0.01 ? stall + 1 : 0
            longestStall = max(longestStall, stall)
        }

        // A few frames either side of the lean's own peak barely move, which is what a smooth
        // turnaround looks like. A clipped term instead holds flat for a quarter of the stroke.
        #expect(longestStall < 12)
        #expect(samples.max()! > BearSwing.trailDegrees)
    }

    /// And it has to cross over near the turnaround, not a long way after it: the lean should
    /// already be answering the new direction by the time the stroke is a fifth of the way back.
    @Test func theLeanTurnsOverAroundTheEndOfTheStroke() {
        // Phase 0 is the end of a stroke: travel has just reversed to positive.
        let justAfterTheTurn = Self.lean(
            velocity: Self.nominalSpeed * sin(0.2 * .pi / 2),
            acceleration: Self.nominalTurn * cos(0.2 * .pi / 2)
        )
        let atTheTurn = Self.lean(velocity: 0, acceleration: Self.nominalTurn)

        #expect(atTheTurn > 0)
        #expect(justAfterTheTurn > atTheTurn)
    }
}
