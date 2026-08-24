import Foundation
import Testing
@testable import ParaBear

struct WindSwayMotionTests {
    // MARK: - The two rules

    /// The two rules, as they reach the bear through the motion the view actually samples.
    /// `BearSwingTrajectoryTests` proves the rules hold over whole trajectories; what is left for
    /// here is that `WindSwayMotion.sample` wires the drift into them the right way round, and at
    /// full size. Sampled at the middle of each stroke, where the rig is at full speed and not yet
    /// turning, and then at the end, where it turns around.
    @Test func theTwoRulesReachTheBearThroughTheSampledMotion() {
        for time in midStrokeTimes(count: 12) {
            let velocity = RigSway.velocity(at: time, seed: 0)
            let lean = sample(at: time).payloadRotationDegrees

            // Rule 1. Positive degrees swings the body left, so it must share the sign of travel.
            #expect(lean.sign == velocity.sign)
            #expect(abs(lean) > BearSwing.trailDegrees * 0.75)
        }

        for time in strokeEndTimes(count: 12) {
            let offset = RigSway.offset(at: time, seed: 0)
            let lean = sample(at: time).payloadRotationDegrees

            // Rule 2. At the far left the offset is negative and the bear carries on left, so the
            // lean has come off the side it held on the way there.
            #expect(lean.sign != offset.sign)
            #expect(abs(lean) > BearSwing.turnDegrees * 0.3)
        }
    }

    // MARK: - Shape

    @Test func zeroIntensityDisablesMotion() {
        let motion = sample(at: 8, intensity: 0)

        #expect(motion.horizontalOffset == 0)
        #expect(motion.canopyHorizontalOffset == 0)
        #expect(motion.payloadHorizontalOffset == 0)
        #expect(motion.verticalBob == 0)
        #expect(motion.canopyRotationDegrees == 0)
        #expect(motion.payloadRotationDegrees == 0)
        #expect(motion.rotationDegrees == 0)
    }

    @Test func intensityScalesMotionLinearly() {
        let full = sample(at: 5.5, intensity: 1)
        let reduced = sample(at: 5.5, intensity: 0.4)

        #expect(abs(Double(reduced.horizontalOffset) - Double(full.horizontalOffset) * 0.4) < 1e-9)
        #expect(abs(Double(reduced.verticalBob) - Double(full.verticalBob) * 0.4) < 1e-9)
        #expect(abs(reduced.canopyRotationDegrees - full.canopyRotationDegrees * 0.4) < 1e-9)
        #expect(abs(reduced.payloadRotationDegrees - full.payloadRotationDegrees * 0.4) < 1e-9)
    }

    @Test func windStyleControlsMotionStrength() {
        let calm = largestMotionMagnitude(for: .calm)
        let windy = largestMotionMagnitude(for: .windy)
        let stormy = largestMotionMagnitude(for: .stormy)

        #expect(calm.horizontal < windy.horizontal)
        #expect(windy.horizontal < stormy.horizontal)
        #expect(calm.vertical < windy.vertical)
        #expect(windy.vertical < stormy.vertical)
        #expect(calm.rotation < windy.rotation)
        #expect(windy.rotation < stormy.rotation)
    }

    @Test func swayStaysWithinItsStatedSizes() {
        for mood in [BearMood.calm, .alert, .urgent] {
            let samples = trace(seconds: 180, mood: mood)

            for motion in samples {
                #expect(abs(Double(motion.horizontalOffset)) <= 15.1)
                #expect(abs(Double(motion.verticalBob)) <= 3.5)
                #expect(abs(motion.canopyRotationDegrees) <= RigSway.canopyLeanDegrees * 1.05)
                // The two rules add, so the most the bear can reach is their sum plus the little
                // the saturating curve allows past nominal.
                #expect(
                    abs(motion.payloadRotationDegrees)
                        <= (BearSwing.trailDegrees + BearSwing.turnDegrees) * 1.05
                )
            }

            #expect(samples.map { abs($0.payloadRotationDegrees) }.max()! > BearSwing.trailDegrees)
            #expect(samples.map { abs(Double($0.horizontalOffset)) }.max()! > 10)
            #expect(samples.map { abs(Double($0.verticalBob)) }.max()! > 3)
        }
    }

    @Test func motionChangesSmoothlyBetweenAnimationFrames() {
        let samples = trace(seconds: 180, mood: .urgent)

        for (previous, current) in zip(samples, samples.dropFirst()) {
            #expect(abs(Double(current.horizontalOffset - previous.horizontalOffset)) < 0.4)
            #expect(abs(Double(current.verticalBob - previous.verticalBob)) < 0.1)
            #expect(abs(current.canopyRotationDegrees - previous.canopyRotationDegrees) < 0.2)
            #expect(abs(current.payloadRotationDegrees - previous.payloadRotationDegrees) < 1)
        }
    }

    @Test func rigAndSuspensionLinesMoveAsOneObject() {
        for motion in trace(seconds: 60) {
            #expect(motion.canopyHorizontalOffset == motion.payloadHorizontalOffset)
            #expect(motion.horizontalOffset == motion.canopyHorizontalOffset)
        }
    }

    /// A plain function of elapsed time: no state, so the same moment always looks the same however
    /// the caller got there, at any frame rate.
    @Test func theSameMomentAlwaysLooksTheSame() {
        #expect(sample(at: 41.25) == sample(at: 41.25))
        #expect(trace(seconds: 30, frameRate: 30).last! == sample(at: 30 - 1.0 / 30, mood: .alert))
    }

    @Test func seedChangesThePathWithoutChangingItsSize() {
        let first = path(seed: 12)
        let second = path(seed: 987)
        let largestGap = zip(first, second)
            .map { abs(Double($0.horizontalOffset - $1.horizontalOffset)) }
            .max() ?? 0
        let firstReach = first.map { abs(Double($0.horizontalOffset)) }.max()!
        let secondReach = second.map { abs(Double($0.horizontalOffset)) }.max()!

        #expect(largestGap > 2)
        #expect(abs(firstReach - secondReach) < 2)
    }

    // MARK: - Helpers

    private func sample(
        at time: TimeInterval,
        mood: BearMood = .calm,
        intensity: Double = 1,
        windStyle: WindStyle = .windy
    ) -> WindSwayMotion {
        WindSwayMotion.sample(
            elapsed: time,
            mood: mood,
            intensity: intensity,
            windStyle: windStyle,
            seed: 0
        )
    }

    private func trace(
        seconds: Double,
        mood: BearMood = .alert,
        windStyle: WindStyle = .windy,
        frameRate: Double = 60
    ) -> [WindSwayMotion] {
        (0..<Int(seconds * frameRate)).map {
            WindSwayMotion.sample(
                elapsed: Double($0) / frameRate,
                mood: mood,
                intensity: 1,
                windStyle: windStyle,
                seed: 0
            )
        }
    }

    private func path(seed: Double) -> [WindSwayMotion] {
        (0..<1_200).map {
            WindSwayMotion.sample(
                elapsed: Double($0) / 20,
                mood: .alert,
                intensity: 1,
                seed: seed
            )
        }
    }

    /// Times at which the main stroke is at full speed, alternating direction.
    private func midStrokeTimes(count: Int) -> [TimeInterval] {
        (0..<count).map { Double($0) * .pi / RigSway.strokeRate }
    }

    /// Times at which the main stroke reaches one of its ends and turns around.
    private func strokeEndTimes(count: Int) -> [TimeInterval] {
        (0..<count).map { (Double($0) * .pi + .pi / 2) / RigSway.strokeRate }
    }

    private func largestMotionMagnitude(for windStyle: WindStyle) -> (
        horizontal: Double,
        vertical: Double,
        rotation: Double
    ) {
        let samples = trace(seconds: 60, windStyle: windStyle)

        return (
            samples.map { abs(Double($0.horizontalOffset)) }.max() ?? 0,
            samples.map { abs(Double($0.verticalBob)) }.max() ?? 0,
            samples.map { max(abs($0.canopyRotationDegrees), abs($0.payloadRotationDegrees)) }.max() ?? 0
        )
    }
}
