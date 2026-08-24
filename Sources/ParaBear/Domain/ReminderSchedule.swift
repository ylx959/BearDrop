import Foundation

/// How long before an event the bear starts announcing it.
enum ReminderLead: String, CaseIterable, Identifiable {
    case fifteen
    case ten
    case five

    var id: String { rawValue }

    var minutes: Int {
        switch self {
        case .fifteen: 15
        case .ten: 10
        case .five: 5
        }
    }

    /// Short enough for a segmented control in a menu, where the row's label carries the rest.
    var title: String { "\(minutes)m" }
}

/// How many flights happen on the approach, before the event starts.
enum ReminderCount: String, CaseIterable, Identifiable {
    case one
    case two
    case three

    var id: String { rawValue }

    var times: Int {
        switch self {
        case .one: 1
        case .two: 2
        case .three: 3
        }
    }

    var title: String { "\(times)" }
}

/// The points on an event's approach the bear flies for, worked out from the two settings rather
/// than listed.
///
/// The rule is one line: **the lead is divided into `approachCount` equal steps, counting down**.
/// Fifteen minutes in three steps is fifteen, ten and five; ten in two is ten and five. That is
/// deliberately the only rule — an app that let you name each reminder's minute separately would
/// need three controls to say what two say here, and every combination it could express that this
/// cannot is one nobody asked for.
///
/// The steps are rounded to whole minutes. Ten in three is 6⅔ and 3⅓ exactly, and the card counts
/// in whole minutes anyway (`relativeCountdown` ceilings it), so an unrounded schedule would fire
/// at a time the card could not display — a flight at 6⅔ minutes showing "in 7 min". Rounding
/// cannot collide two steps into one: the tightest case here is five minutes in three, which is
/// 5/3/2.
struct ReminderSchedule: Equatable {
    let leadMinutes: Int
    let approachCount: Int

    /// How long after the start the last flight goes — and, with it, the end of the event's life.
    ///
    /// This one is **not** a setting, and that is a decision rather than an omission. It is not
    /// really "when to remind me again"; it is *when the bear is done with this event*, and the
    /// event stays in front of everything behind it until then. Stretching it to a quarter of an
    /// hour would bring back the exact problem `EventTimelineViewModel` retires events to avoid:
    /// a meeting starting at 10:15 gets no warning at all if the 10:00 one is still standing in
    /// front of it at 10:15. Five minutes is long enough that whoever was going has gone, and
    /// short enough that back-to-back meetings still get their run-up.
    static let underwayDelay: TimeInterval = 5 * 60

    init(leadMinutes: Int, approachCount: Int) {
        self.leadMinutes = max(1, leadMinutes)
        self.approachCount = max(1, approachCount)
    }

    init(lead: ReminderLead, count: ReminderCount) {
        self.init(leadMinutes: lead.minutes, approachCount: count.times)
    }

    /// Every flight this schedule makes, in the order they happen.
    ///
    /// The approach, then the start itself — which is always flown and is not one of the counted
    /// reminders — then the handover once the event is underway.
    var milestones: [ReminderMilestone] {
        approachOffsets.map { ReminderMilestone(offsetFromStart: $0, isLast: false) }
            + [
                ReminderMilestone(offsetFromStart: 0, isLast: false),
                ReminderMilestone(offsetFromStart: Self.underwayDelay, isLast: true)
            ]
    }

    /// Ascending, so the furthest-out flight is first — the same order `milestones` is read in.
    private var approachOffsets: [TimeInterval] {
        (1...approachCount).reversed().map { step in
            let minutes = (Double(leadMinutes) * Double(step) / Double(approachCount)).rounded()
            return -minutes * 60
        }
    }

    /// The schedule in words: "15, 10 and 5 min before & at the start".
    ///
    /// Two controls reading "15m" and "3" state the *inputs* to the rule and leave the reader to
    /// divide one by the other to find out when the bear actually turns up. This states the answer.
    /// It is built from `approachOffsets` — the very list the flights are made from — rather than
    /// written out alongside it, so it cannot end up describing a schedule that is not in force.
    var summary: String {
        let minutes = approachOffsets.map { String(Int(-$0 / 60)) }
        let approach: String

        switch minutes.count {
        case 1:
            approach = minutes[0]
        default:
            approach = minutes.dropLast().joined(separator: ", ") + " and " + minutes[minutes.count - 1]
        }

        return "\(approach) min before & at the start"
    }

    /// Read from the far end backwards, so the most advanced milestone the event has reached is the
    /// one returned. Milestones are not caught up on: `milestonesHandled(by:)` marks everything
    /// earlier as done, so an app that was asleep through the first three does not fire them all at
    /// once on waking.
    func dueMilestone(for secondsUntilStart: TimeInterval) -> ReminderMilestone? {
        let sinceStart = -secondsUntilStart

        return milestones.last { $0.offsetFromStart <= sinceStart }
    }

    func milestonesHandled(by milestone: ReminderMilestone) -> [ReminderMilestone] {
        milestones.filter { $0.offsetFromStart <= milestone.offsetFromStart }
    }
}
