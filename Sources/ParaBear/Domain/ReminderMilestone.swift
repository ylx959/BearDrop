import Foundation

enum ReminderMilestone: CaseIterable, Equatable {
    case tenMinutes
    case fiveMinutes
    case threeMinutes
    case starting

    static func dueMilestone(for secondsUntilStart: TimeInterval) -> ReminderMilestone? {
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
        }
    }
}
