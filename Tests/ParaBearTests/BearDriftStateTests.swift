import Foundation
import Testing
@testable import ParaBear

struct BearDriftStateTests {
    @MainActor
    @Test func nothingIsCarryingTheRigToBeginWith() {
        #expect(!BearDriftState().isBeingCarried)
    }

    /// The window has to move on the same event that moved the pointer, so carrying reports
    /// straight through rather than parking a value for the drift timer to pick up later.
    @MainActor
    @Test func carryingReportsThePointerThroughImmediately() {
        let state = BearDriftState()
        var reported: [CGPoint] = []
        state.onCarry = { reported.append($0) }

        state.carry(toScreenPoint: CGPoint(x: 120, y: 640))
        state.carry(toScreenPoint: CGPoint(x: 180, y: 610))

        #expect(state.isBeingCarried)
        #expect(reported == [CGPoint(x: 120, y: 640), CGPoint(x: 180, y: 610)])
    }

    @MainActor
    @Test func droppingHandsTheRigBackToTheDescent() {
        let state = BearDriftState()
        var drops = 0
        state.onDrop = { drops += 1 }

        state.carry(toScreenPoint: CGPoint(x: 60, y: 60))
        state.drop()

        #expect(!state.isBeingCarried)
        #expect(drops == 1)
    }

    /// A drop with nothing held would otherwise re-seat the sway and restart the flight clock for
    /// no reason — every stray gesture end would nudge the descent.
    @MainActor
    @Test func droppingWhenNothingIsHeldDoesNothing() {
        let state = BearDriftState()
        var drops = 0
        state.onDrop = { drops += 1 }

        state.drop()

        #expect(drops == 0)
    }

    @MainActor
    @Test func newFlightClearsAnythingLeftOverFromTheLastOne() {
        let state = BearDriftState()
        state.carry(toScreenPoint: CGPoint(x: 200, y: 30))
        state.carriedSwingDegrees = 7
        state.descentTravel = BearSwing.Travel(
            velocity: 40, acceleration: 5, nominalSpeed: 100, nominalTurn: 20
        )

        state.reset()

        #expect(!state.isBeingCarried)
        #expect(state.carriedSwingDegrees == nil)
        #expect(state.descentTravel == .still)
    }
}
