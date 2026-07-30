import Foundation
import Testing
@testable import ParaBear

struct CarriedSwingTests {
    private static let dt = 1.0 / 240
    /// The bear's own swing frequency, which is roughly the rate a hand shakes at — see
    /// `CarriedSwing.stiffness` for why that matters.
    private static let swingHertz = CarriedSwing.stiffness.squareRoot() / (2 * .pi)

    private static func advance(
        from state: CarriedSwing.State,
        handVelocity: Double,
        handAcceleration: Double = 0,
        seconds: Double
    ) -> CarriedSwing.State {
        var current = state
        for _ in 0..<Int(seconds / dt) {
            current = CarriedSwing.advance(
                current,
                handVelocity: handVelocity,
                handAcceleration: handAcceleration,
                dt: dt
            )
        }
        return current
    }

    private static func trace(
        from state: CarriedSwing.State,
        handVelocity: Double,
        seconds: Double
    ) -> [Double] {
        var current = state
        return (0..<Int(seconds / dt)).map { _ in
            current = CarriedSwing.advance(
                current,
                handVelocity: handVelocity,
                handAcceleration: 0,
                dt: dt
            )
            return current.degrees
        }
    }

    /// Shakes the hand back and forth by `amplitude` points at `hertz` and reports the angle each
    /// step, so a test can look at how far the bear ends up swinging.
    private static func shake(
        amplitude: Double,
        hertz: Double,
        seconds: Double
    ) -> [Double] {
        let rate = 2 * .pi * hertz
        var current = CarriedSwing.State.level

        return (0..<Int(seconds / dt)).map { step in
            let time = Double(step) * dt
            current = CarriedSwing.advance(
                current,
                handVelocity: amplitude * rate * cos(rate * time),
                handAcceleration: -amplitude * rate * rate * sin(rate * time),
                dt: dt
            )
            return current.degrees
        }
    }

    // MARK: - Shaking

    /// The headline behaviour: shake it twice as far and it swings much harder, with no rule
    /// anywhere saying so — it falls out of the hand's acceleration driving a pendulum.
    /// Even well above its own frequency — a fast waggle rather than a swing — it must still
    /// answer, just less. This is the case that was completely dead with a slower bear.
    @Test func aFastWaggleStillSwingsIt() {
        let gentle = Self.shake(amplitude: 40, hertz: 2.6, seconds: 6).map(abs).max()!
        let violent = Self.shake(amplitude: 180, hertz: 2.6, seconds: 6).map(abs).max()!

        #expect(gentle > 4)
        #expect(violent > 20)
        #expect(violent > gentle * 2.5)
    }

    @Test func shakingHarderSwingsItHarder() {
        let gentle = Self.shake(amplitude: 40, hertz: Self.swingHertz, seconds: 6).map(abs).max()!
        let firm = Self.shake(amplitude: 90, hertz: Self.swingHertz, seconds: 6).map(abs).max()!
        let violent = Self.shake(amplitude: 180, hertz: Self.swingHertz, seconds: 6).map(abs).max()!

        #expect(gentle < firm)
        #expect(firm < violent)
        // And the gap is worth looking at, not a couple of degrees.
        #expect(violent > gentle * 2.5)
        #expect(violent > 45)
    }

    /// On a rope, each shake adds to the last. The swing must keep growing over the first few
    /// cycles rather than reaching its size on the first one.
    @Test func rhythmicShakingBuildsUpOverSeveralSwings() {
        let samples = Self.shake(amplitude: 60, hertz: Self.swingHertz, seconds: 8)
        let stepsPerSecond = Int(1 / Self.dt)
        let perSecond = stride(from: 0, to: samples.count, by: stepsPerSecond).map { start in
            samples[start..<min(start + stepsPerSecond, samples.count)].map(abs).max()!
        }

        #expect(perSecond[1] > perSecond[0] * 1.3)
        #expect(perSecond[3] > perSecond[1])
    }

    /// A wide swing is slower than a narrow one, because the restoring pull is `sin` of the angle.
    /// This is what makes it read as a rope rather than a spring. The gap is smaller than the
    /// textbook figure because the swing is damped and has already narrowed by the second crossing.
    @Test func wideSwingsAreSlowerThanNarrowOnes() {
        let narrow = Self.period(startingAt: 5)
        let wide = Self.period(startingAt: 65)

        #expect(wide > narrow * 1.02)
    }

    /// Free swing period, measured from the time between the first two crossings of level.
    private static func period(startingAt degrees: Double) -> Double {
        var state = CarriedSwing.State(degrees: degrees, angularVelocity: 0)
        var crossings: [Double] = []
        var previous = state.degrees

        for step in 0..<Int(6 / dt) {
            state = CarriedSwing.advance(state, handVelocity: 0, handAcceleration: 0, dt: dt)
            if state.degrees.sign != previous.sign { crossings.append(Double(step) * dt) }
            previous = state.degrees
            if crossings.count == 2 { break }
        }

        return crossings[1] - crossings[0]
    }

    // MARK: - Carrying

    @Test func pullingItOneWayTrailsTheBearTheOther() {
        let right = Self.advance(from: .level, handVelocity: 500, seconds: 3)
        let left = Self.advance(from: .level, handVelocity: -500, seconds: 3)

        #expect(right.degrees > 0)
        #expect(left.degrees < 0)
        #expect(abs(right.degrees - -left.degrees) < 0.001)
    }

    @Test func draggingFasterTrailsFurther() {
        let gentle = Self.advance(from: .level, handVelocity: 200, seconds: 3)
        let brisk = Self.advance(from: .level, handVelocity: 800, seconds: 3)

        #expect(brisk.degrees > gentle.degrees)
    }

    /// The reason there is an integrator here at all: a hand that stops sends no more events, and
    /// the swing has to keep moving on its own instead of locking at its last angle.
    @Test func theSwingKeepsMovingAfterTheHandStops() {
        let pulled = Self.advance(from: .level, handVelocity: 700, seconds: 1)
        #expect(pulled.degrees > 5)

        // With the hand still, the bear must carry on past level rather than easing back to it.
        let coasting = Self.trace(from: pulled, handVelocity: 0, seconds: 1.5)
        #expect(coasting.contains { $0 < -0.5 })
        #expect(coasting.map(abs).max()! > 2)
    }

    @Test func theSwingSettlesRatherThanRingingForever() {
        let pulled = Self.advance(from: .level, handVelocity: 700, seconds: 1)
        let muchLater = Self.advance(from: pulled, handVelocity: 0, seconds: 20)

        #expect(abs(muchLater.degrees) < 0.5)
    }

    /// Stopping short throws the bear onward: the sudden deceleration is a push the other way.
    @Test func stoppingShortThrowsTheBearForward() {
        let moving = Self.advance(from: .level, handVelocity: 600, seconds: 1)
        let braking = Self.advance(
            from: moving,
            handVelocity: 600,
            handAcceleration: -6_000,
            seconds: 0.1
        )

        #expect(braking.degrees < moving.degrees)
    }

    @Test func theSwingStaysBelowTheTopOfItsArc() {
        let violent = Self.advance(
            from: .level,
            handVelocity: 20_000,
            handAcceleration: 200_000,
            seconds: 4
        )

        #expect(abs(violent.degrees) <= CarriedSwing.maxDegrees + 0.001)
        // Below 90, so the rope is always still pulling it home rather than over the top.
        #expect(CarriedSwing.maxDegrees < 90)
        #expect(CarriedSwing.restoring(CarriedSwing.maxDegrees) > 0)
    }
}
