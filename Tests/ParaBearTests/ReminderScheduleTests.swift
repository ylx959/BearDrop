import Foundation
import Testing
@testable import ParaBear

struct ReminderScheduleTests {
    private func schedule(_ lead: ReminderLead, _ count: ReminderCount) -> ReminderSchedule {
        ReminderSchedule(lead: lead, count: count)
    }

    /// Minutes before the start, in the order they are flown — the readable form of the offsets.
    private func approach(_ schedule: ReminderSchedule) -> [Int] {
        schedule.milestones
            .filter { $0.offsetFromStart < 0 }
            .map { Int(-$0.offsetFromStart / 60) }
    }

    /// The whole rule, stated once: the lead divided into as many equal steps as were asked for.
    @Test func theLeadIsDividedIntoAsManyStepsAsWereAskedFor() {
        #expect(approach(schedule(.fifteen, .three)) == [15, 10, 5])
        #expect(approach(schedule(.fifteen, .two)) == [15, 8])
        #expect(approach(schedule(.fifteen, .one)) == [15])
        #expect(approach(schedule(.ten, .two)) == [10, 5])
        #expect(approach(schedule(.five, .one)) == [5])
    }

    /// The default, and the one number worth pinning: ten minutes in three flights is 10/7/3, which
    /// is the schedule the bear had when it was hard-coded (10/5/3) to within a minute. Upgrading
    /// must not change what the app does.
    @MainActor
    @Test func theDefaultScheduleIsWhatTheBearAlwaysDid() {
        let settings = SettingsStore()

        #expect(approach(schedule(settings.reminderLead, settings.reminderCount)) == [10, 7, 3])
    }

    /// Rounding to whole minutes is only safe if it cannot fold two steps into one. Five minutes in
    /// three is the tightest this can get, and every combination the menu offers is checked rather
    /// than that one argued about.
    @Test func noTwoFlightsEverLandOnTheSameMinute() {
        for lead in ReminderLead.allCases {
            for count in ReminderCount.allCases {
                let offsets = schedule(lead, count).milestones.map(\.offsetFromStart)

                #expect(Set(offsets).count == offsets.count, "\(lead.title) × \(count.title)")
                // And they are whole minutes, which is what the card can actually display.
                #expect(offsets.allSatisfy { $0.truncatingRemainder(dividingBy: 60) == 0 })
            }
        }
    }

    /// The count names the *approach*. The start itself is always flown and is not one of them, and
    /// neither is the handover — so asking for one reminder still gets three flights.
    @Test func theStartAndTheHandoverAreFlownOnTopOfTheCount() {
        for lead in ReminderLead.allCases {
            for count in ReminderCount.allCases {
                let milestones = schedule(lead, count).milestones

                #expect(milestones.count == count.times + 2)
                #expect(milestones.contains { $0.offsetFromStart == 0 })
                #expect(milestones.last?.offsetFromStart == ReminderSchedule.underwayDelay)
            }
        }
    }

    /// Exactly one milestone ends the event, and it is the one furthest along.
    @Test func onlyTheFinalMilestoneRetiresTheEvent() {
        for lead in ReminderLead.allCases {
            for count in ReminderCount.allCases {
                let milestones = schedule(lead, count).milestones

                #expect(milestones.filter(\.isLast).count == 1)
                #expect(milestones.last?.isLast == true)
            }
        }
    }

    /// The sentence in the menu names exactly the minutes the bear actually flies at — checked
    /// against the offsets rather than against a second copy of the expected wording, since the
    /// whole point of deriving it is that it cannot describe a schedule that is not in force.
    @Test func theSummaryNamesTheFlightsItActuallyMakes() {
        for lead in ReminderLead.allCases {
            for count in ReminderCount.allCases {
                let schedule = schedule(lead, count)
                let named = schedule.summary
                    .prefix(while: { $0 != "m" })
                    .split(whereSeparator: { !$0.isNumber })
                    .map { Int($0)! }

                #expect(named == approach(schedule), "\(lead.title) × \(count.title): \(schedule.summary)")
            }
        }
    }

    @Test func theSummaryReadsAsASentence() {
        #expect(ReminderSchedule(lead: .fifteen, count: .three).summary
            == "15, 10 and 5 min before & at the start")
        #expect(ReminderSchedule(lead: .ten, count: .two).summary
            == "10 and 5 min before & at the start")
        #expect(ReminderSchedule(lead: .five, count: .one).summary
            == "5 min before & at the start")
    }

    @Test func nothingIsDueWhileTheEventIsStillFarOff() {
        #expect(schedule(.fifteen, .three).dueMilestone(for: 20 * 60) == nil)
        #expect(schedule(.five, .one).dueMilestone(for: 6 * 60) == nil)
    }

    /// Minutes from the start of the flight that is due — negative before it, zero at it. Stated in
    /// minutes because that is the unit the schedule is chosen in, and it keeps the expectations
    /// below readable next to the setting that produced them.
    private func dueMinutes(_ schedule: ReminderSchedule, at secondsUntilStart: TimeInterval) -> Double? {
        schedule.dueMilestone(for: secondsUntilStart).map { $0.offsetFromStart / 60 }
    }

    @Test func theMostAdvancedFlightReachedIsTheOneDue() {
        let fifteenInThree = schedule(.fifteen, .three)

        #expect(dueMinutes(fifteenInThree, at: 14 * 60) == -15)
        #expect(dueMinutes(fifteenInThree, at: 9 * 60) == -10)
        #expect(dueMinutes(fifteenInThree, at: 60) == -5)
        #expect(dueMinutes(fifteenInThree, at: 0) == 0)
        #expect(dueMinutes(fifteenInThree, at: -60) == 0)
    }

    /// The one last flight, five minutes after the meeting began — and the end of its life.
    @Test func theLastFlightGoesOnceTheEventIsUnderway() {
        let due = schedule(.ten, .three).dueMilestone(for: -ReminderSchedule.underwayDelay)

        #expect(due?.isLast == true)
        #expect(schedule(.ten, .three).dueMilestone(for: -30 * 60)?.isLast == true)
    }

    /// Milestones are not caught up on. An app asleep through the first three wakes to one flight,
    /// not four.
    @Test func reachingAFlightMarksEveryEarlierOneAsDone() {
        for lead in ReminderLead.allCases {
            for count in ReminderCount.allCases {
                let schedule = schedule(lead, count)

                for milestone in schedule.milestones {
                    let handled = schedule.milestonesHandled(by: milestone)

                    #expect(handled.last == milestone)
                    #expect(handled == Array(schedule.milestones.prefix(handled.count)))
                }
            }
        }
    }

    /// What makes changing the setting mid-event safe, and the reason `EventTimelineViewModel` can
    /// read the schedule fresh on every tick rather than pinning one per event.
    ///
    /// A due milestone is only ever one already *passed*, and everything at or before it is marked
    /// done in the same pass. So whichever schedule the next tick reads, the only flights it can
    /// still make are ones whose moment has not arrived — a longer lead cannot retrospectively fire
    /// the flights it would have made, and a shorter one cannot replay a flight already made.
    @Test func aDueFlightIsAlwaysOneThatHasAlreadyPassed() {
        for lead in ReminderLead.allCases {
            for count in ReminderCount.allCases {
                let schedule = schedule(lead, count)

                for secondsUntilStart in stride(from: 1200.0, through: -1200.0, by: -5) {
                    guard let due = schedule.dueMilestone(for: secondsUntilStart) else { continue }

                    #expect(due.offsetFromStart <= -secondsUntilStart)
                }
            }
        }
    }
}
