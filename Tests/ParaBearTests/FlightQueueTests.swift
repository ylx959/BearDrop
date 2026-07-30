import Foundation
import Testing
@testable import ParaBear

struct FlightQueueTests {
    @Test func theFirstRequestFliesStraightAway() {
        var queue = FlightQueue()

        #expect(queue.request(6) == 6)
        #expect(queue.isFlying)
    }

    /// The point of the whole type: a bear halfway down the screen used to vanish and reappear at
    /// the top whenever a second milestone came due.
    @Test func aRequestArrivingMidFlightDoesNotInterruptIt() {
        var queue = FlightQueue()
        _ = queue.request(6)

        #expect(queue.request(6) == nil)
        #expect(queue.pending == 6)
    }

    @Test func theWaitingFlightGoesWhenTheCurrentOneLands() {
        var queue = FlightQueue()
        _ = queue.request(6)
        _ = queue.request(9)

        #expect(queue.finished() == 9)
        #expect(queue.isFlying)
        #expect(queue.pending == nil)
    }

    /// Only one waits. The flight carries no message of its own — the card is read live — so a
    /// burst of milestones would otherwise be several identical flights in a row.
    @Test func aBurstOfRemindersLeavesExactlyOneFlightWaiting() {
        var queue = FlightQueue()
        _ = queue.request(6)

        #expect(queue.request(6) == nil)
        #expect(queue.request(9) == nil)
        #expect(queue.request(12) == nil)

        #expect(queue.finished() == 12)
        #expect(queue.finished() == nil)
        #expect(!queue.isFlying)
    }

    @Test func landingWithNothingWaitingEndsTheFlight() {
        var queue = FlightQueue()
        _ = queue.request(6)

        #expect(queue.finished() == nil)
        #expect(!queue.isFlying)
    }

    /// Switching the bear off drops what was waiting. A reminder that turns up after being
    /// dismissed is worse than one that never comes.
    @Test func switchingTheBearOffDropsWhatWasWaiting() {
        var queue = FlightQueue()
        _ = queue.request(6)
        _ = queue.request(9)

        queue.cancel()

        #expect(!queue.isFlying)
        #expect(queue.pending == nil)
        #expect(queue.finished() == nil)
    }

    @Test func theQueueTakesFlightsAgainAfterBeingCancelled() {
        var queue = FlightQueue()
        _ = queue.request(6)
        queue.cancel()

        #expect(queue.request(6) == 6)
    }
}
