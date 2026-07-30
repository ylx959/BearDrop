import Foundation
import Testing
@testable import ParaBear

@MainActor
struct EventTimelineViewModelTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func event(
        _ id: String,
        startingIn minutes: Double,
        lasting duration: Double = 30
    ) -> CalendarEvent {
        let start = now.addingTimeInterval(minutes * 60)

        return CalendarEvent(
            id: id,
            title: id,
            startDate: start,
            endDate: start.addingTimeInterval(duration * 60),
            calendarTitle: "Work"
        )
    }

    @Test func theSoonestEventStillToComeIsTheOneShown() {
        let events = [event("a", startingIn: 8), event("b", startingIn: 25)]

        #expect(
            EventTimelineViewModel.nextEvent(from: events, finished: [], now: now)?.id == "a"
        )
    }

    @Test func anEventThatHasAlreadyEndedIsSkipped() {
        let events = [event("over", startingIn: -90), event("next", startingIn: 12)]

        #expect(
            EventTimelineViewModel.nextEvent(from: events, finished: [], now: now)?.id == "next"
        )
    }

    /// The reason the finished set exists. A meeting in progress used to stand in front of
    /// everything behind it until its end time, so back-to-back events got no warning at all.
    @Test func aFinishedEventNoLongerBlocksTheOneBehindIt() {
        let running = event("running", startingIn: -6)
        let next = event("next", startingIn: 9)
        let events = [running, next]

        #expect(
            EventTimelineViewModel.nextEvent(from: events, finished: [], now: now)?.id == "running"
        )

        let finished: Set = [EventTimelineViewModel.eventKey(for: running)]
        #expect(
            EventTimelineViewModel.nextEvent(from: events, finished: finished, now: now)?.id
                == "next"
        )
    }

    @Test func nothingIsShownOnceEveryEventIsDoneWith() {
        let only = event("only", startingIn: -6)
        let finished: Set = [EventTimelineViewModel.eventKey(for: only)]

        #expect(EventTimelineViewModel.nextEvent(from: [only], finished: finished, now: now) == nil)
    }

    /// The last milestone hands over to the next event. With nothing behind it the bear would fly
    /// in only to say there is nothing to say.
    @Test func theFinalFlightIsSkippedWhenThereIsNothingToHandOverTo() {
        #expect(!EventTimelineViewModel.isWorthFlying(.underway, handingOverTo: nil))
        #expect(
            EventTimelineViewModel.isWorthFlying(.underway, handingOverTo: event("next", startingIn: 9))
        )
    }

    /// Every other milestone has its own event to announce, so an empty diary behind it changes
    /// nothing.
    @Test func theApproachMilestonesAlwaysFly() {
        for milestone in ReminderMilestone.allCases where !milestone.isLast {
            #expect(EventTimelineViewModel.isWorthFlying(milestone, handingOverTo: nil))
        }
    }

    /// A repeating event carries the same identifier at every one of its starts, so the key has to
    /// name the occurrence — otherwise finishing with this morning's stand-up silences tomorrow's.
    @Test func twoOccurrencesOfTheSameEventAreToldApart() {
        let today = event("standup", startingIn: -6)
        let tomorrow = event("standup", startingIn: 24 * 60)

        #expect(
            EventTimelineViewModel.eventKey(for: today)
                != EventTimelineViewModel.eventKey(for: tomorrow)
        )

        let finished: Set = [EventTimelineViewModel.eventKey(for: today)]
        #expect(
            EventTimelineViewModel.nextEvent(from: [today, tomorrow], finished: finished, now: now)?
                .startDate == tomorrow.startDate
        )
    }
}
