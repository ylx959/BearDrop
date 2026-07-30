import Foundation

/// Decides whether a reminder flies now or waits for the one already in the air.
///
/// Reminders arrive in bursts. Two calendar events back to back put three or four milestones inside
/// ten minutes — see `ReminderMilestone` — and every one of them used to call straight into the
/// overlay, which restarted the flight where it stood: a bear halfway down the screen would vanish
/// and reappear at the top. Worse, the restart reset the drift state, so a reminder arriving while
/// the rig was in someone's hand pulled it out of their hand.
///
/// So a flight in progress is left alone and the next one waits behind it.
///
/// **At most one waits.** A queue would be wrong here: the flight carries no message of its own —
/// the card reads the view model live, so it always shows the current event and the current
/// countdown whenever it happens to be drawn. Three queued flights are therefore three identical
/// flights in a row saying the same thing, which is noise, not information. The last request wins,
/// because the duration is the one thing a request does carry.
struct FlightQueue: Equatable {
    private(set) var isFlying = false
    /// The flight waiting for the current one to finish, if any.
    private(set) var pending: TimeInterval?

    /// Asks to fly. Returns the duration to fly *now*, or `nil` if it was put behind the flight
    /// already in the air.
    mutating func request(_ duration: TimeInterval) -> TimeInterval? {
        guard !isFlying else {
            pending = duration
            return nil
        }

        isFlying = true
        pending = nil
        return duration
    }

    /// The flight in the air has left the screen. Returns the one that was waiting, if any.
    mutating func finished() -> TimeInterval? {
        isFlying = false

        guard let waiting = pending else { return nil }

        pending = nil
        isFlying = true
        return waiting
    }

    /// Everything stops — the bear was switched off, not merely landed. Whatever was waiting is
    /// dropped rather than played later: it is a reminder, and one that arrives after being
    /// dismissed is worse than one that never comes.
    mutating func cancel() {
        isFlying = false
        pending = nil
    }
}
