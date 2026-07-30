import Foundation

/// The points on an event's approach worth flying the bear for.
///
/// Four of them run down to the start. The fifth runs past it: `underway` is the one last flight a
/// few minutes *after* the meeting began, and it is also the point at which the event is done with
/// — see `EventTimelineViewModel`. Something has to end an event's life, and its end time is the
/// wrong thing to use: a meeting that ran long, or one nobody left, would sit in front of
/// everything behind it for as long as the calendar says it lasts, and the events after it would
/// get no warning at all. A few minutes past the hour, whoever was going has gone.
enum ReminderMilestone: CaseIterable, Equatable {
    case tenMinutes
    case fiveMinutes
    case threeMinutes
    case starting
    case underway

    /// How long after the start the last flight goes.
    static let underwayDelay: TimeInterval = 5 * 60

    /// Read from the far end backwards, so the most advanced milestone the event has reached is the
    /// one returned. Milestones are not caught up on: `milestonesHandled(by:)` marks everything
    /// earlier as done, so an app that was asleep through the first three does not fire them all at
    /// once on waking.
    static func dueMilestone(for secondsUntilStart: TimeInterval) -> ReminderMilestone? {
        if secondsUntilStart <= -underwayDelay {
            return .underway
        }

        if secondsUntilStart <= 0 {
            return .starting
        }

        if secondsUntilStart <= 3 * 60 {
            return .threeMinutes
        }

        if secondsUntilStart <= 5 * 60 {
            return .fiveMinutes
        }

        if secondsUntilStart <= 10 * 60 {
            return .tenMinutes
        }

        return nil
    }

    static func milestonesHandled(by milestone: ReminderMilestone) -> [ReminderMilestone] {
        switch milestone {
        case .tenMinutes:
            [.tenMinutes]
        case .fiveMinutes:
            [.tenMinutes, .fiveMinutes]
        case .threeMinutes:
            [.tenMinutes, .fiveMinutes, .threeMinutes]
        case .starting:
            [.tenMinutes, .fiveMinutes, .threeMinutes, .starting]
        case .underway:
            [.tenMinutes, .fiveMinutes, .threeMinutes, .starting, .underway]
        }
    }

    /// Whether reaching this milestone is the end of the event as far as the bear is concerned.
    var isLast: Bool { self == .underway }
}
