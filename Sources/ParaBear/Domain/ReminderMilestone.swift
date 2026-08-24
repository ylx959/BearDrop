import Foundation

/// A point on an event's approach worth flying the bear for, stated as its offset from the event's
/// start: negative before it, zero at it, positive after.
///
/// This used to be a fixed five-case enum — ten, five and three minutes out, the start, and one
/// last flight five minutes in — with the times buried in an `if` ladder. The approach is now the
/// user's to choose (see `ReminderSchedule`), so a milestone can no longer name itself: what
/// identifies it is where it sits on the approach, and nothing else.
struct ReminderMilestone: Equatable, Hashable {
    /// Seconds from the event's start. Negative before it, zero at it, positive after.
    let offsetFromStart: TimeInterval

    /// Whether reaching this milestone is the end of the event as far as the bear is concerned.
    ///
    /// Exactly one milestone in a schedule carries it, and it is the one furthest along. No two
    /// milestones in a schedule share an offset, so this never has to be reconciled against one:
    /// it is a fact about the offset, not a second opinion alongside it.
    let isLast: Bool
}
