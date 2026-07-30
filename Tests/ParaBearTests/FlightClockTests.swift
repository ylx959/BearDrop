import Foundation
import Testing
@testable import ParaBear

struct FlightClockTests {
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    @Test func framesArrivingOnTimeAddUpToTheTimeThatPassed() {
        var clock = FlightClock(startingAt: start)

        for frame in 1...60 {
            clock.frame(at: start.addingTimeInterval(Double(frame) / 60))
        }

        #expect(abs(clock.elapsed - 1) < 1e-9)
    }

    /// The whole point: the menu stops the drift timer, and when it starts again the flight has to
    /// be where it was left, not where the wall clock says it should have got to.
    @Test func theFlightPicksUpWhereTheMenuStoppedIt() {
        var clock = FlightClock(startingAt: start)
        var now = start

        for _ in 0..<30 {
            now += 1 / 60
            clock.frame(at: now)
        }
        let beforeTheMenu = clock.elapsed

        // Three seconds of menu, during which not one frame is drawn.
        now += 3
        clock.frame(at: now)

        #expect(clock.elapsed - beforeTheMenu <= FlightClock.maxStep + 1e-9)
    }

    @Test func noOneFrameIsWorthMoreThanTheLimit() {
        var clock = FlightClock(startingAt: start)

        clock.frame(at: start.addingTimeInterval(45))

        #expect(clock.elapsed == FlightClock.maxStep)
    }

    /// A held flight spends its frames without drawing them. Banking them instead would only move
    /// the jump to the moment the bear was let go.
    @Test func timeHeldIsSpentRatherThanBanked() {
        var clock = FlightClock(startingAt: start)
        var now = start

        for _ in 0..<20 {
            now += 1 / 60
            clock.frame(at: now, running: false)
        }

        #expect(clock.elapsed == 0)

        now += 1 / 60
        clock.frame(at: now)

        #expect(abs(clock.elapsed - 1.0 / 60) < 1e-9)
    }

    /// A held frame still reports how long it was, because the carried swing is integrated on it.
    @Test func aHeldFrameStillReportsItsLength() {
        var clock = FlightClock(startingAt: start)

        let step = clock.frame(at: start.addingTimeInterval(1 / 60), running: false)

        #expect(abs(step - 1.0 / 60) < 1e-9)
    }

    @Test func restartingBeginsANewFlightAtTheStartOfTheCurves() {
        var clock = FlightClock(startingAt: start)
        clock.frame(at: start.addingTimeInterval(2))

        clock.restart(at: start.addingTimeInterval(10))

        #expect(clock.elapsed == 0)

        clock.frame(at: start.addingTimeInterval(10 + 1 / 60))
        #expect(abs(clock.elapsed - 1.0 / 60) < 1e-9)
    }

    /// A clock stamped backwards — a wall clock adjustment, say — must not run the flight in
    /// reverse.
    @Test func timeNeverRunsBackwards() {
        var clock = FlightClock(startingAt: start)
        clock.frame(at: start.addingTimeInterval(1 / 60))
        let elapsed = clock.elapsed

        clock.frame(at: start.addingTimeInterval(-5))

        #expect(clock.elapsed == elapsed)
    }
}
