import Foundation
import Testing
@testable import ParaBear

struct ReminderMilestoneTests {
    @Test func nothingIsDueWhileTheEventIsStillFarOff() {
        #expect(ReminderMilestone.dueMilestone(for: 20 * 60) == nil)
    }

    @Test func eachApproachMilestoneIsDueInsideItsOwnWindow() {
        #expect(ReminderMilestone.dueMilestone(for: 9 * 60) == .tenMinutes)
        #expect(ReminderMilestone.dueMilestone(for: 4 * 60) == .fiveMinutes)
        #expect(ReminderMilestone.dueMilestone(for: 2 * 60) == .threeMinutes)
        #expect(ReminderMilestone.dueMilestone(for: 0) == .starting)
    }

    /// The one last flight, five minutes after the meeting began.
    @Test func theLastFlightGoesOnceTheEventIsUnderway() {
        #expect(ReminderMilestone.dueMilestone(for: -60) == .starting)
        #expect(
            ReminderMilestone.dueMilestone(for: -ReminderMilestone.underwayDelay) == .underway
        )
        #expect(ReminderMilestone.dueMilestone(for: -30 * 60) == .underway)
    }

    /// Milestones are not caught up on. An app asleep through the first three wakes to one flight,
    /// not four.
    @Test func reachingAMilestoneMarksEveryEarlierOneAsDone() {
        for milestone in ReminderMilestone.allCases {
            let handled = ReminderMilestone.milestonesHandled(by: milestone)

            #expect(handled.last == milestone)
            #expect(handled == Array(ReminderMilestone.allCases.prefix(handled.count)))
        }
    }

    @Test func theLastMilestoneAccountsForAllOfThem() {
        #expect(
            ReminderMilestone.milestonesHandled(by: .underway) == ReminderMilestone.allCases
        )
    }

    /// Exactly one milestone ends the event, and it is the one furthest along.
    @Test func onlyTheFinalMilestoneRetiresTheEvent() {
        #expect(ReminderMilestone.allCases.filter(\.isLast) == [.underway])
        #expect(ReminderMilestone.allCases.last?.isLast == true)
    }
}
