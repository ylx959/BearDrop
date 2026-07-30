import Foundation

/// The flight's own clock. It counts the time the flight was actually **drawn** for, which is not
/// the same as the time that has passed on the wall.
///
/// The drift loop runs on a `Timer` in the default run-loop mode, and opening the menu bar's menu
/// puts the run loop into event-tracking mode, where that timer does not fire at all. So the rig
/// stops while the menu is open — which is fine, and reads as the bear waiting. What is not fine is
/// what wall-clock elapsed does next: the moment the menu closes it hands the sweep every second
/// the menu was open, and the curve is read at a time nothing was ever drawn at, so the rig jumps
/// sideways to wherever it "should" have got to. Counting only the frames that happened means the
/// flight sets off again from exactly where it was left.
///
/// The same clamp covers a frame that merely ran late, for the same reason: no one frame may
/// advance the flight by more than `maxStep`, however long the gap in front of it was.
struct FlightClock: Equatable {
    /// The most one frame may be worth. A quarter of a second of stall is a visible jump; a
    /// fifteenth is four frames' worth, which is not.
    static let maxStep: TimeInterval = 1 / 15

    /// How long the flight has been drawn for.
    private(set) var elapsed: TimeInterval = 0
    private var lastFrame: Date

    init(startingAt now: Date) {
        lastFrame = now
    }

    /// Takes a frame and returns how much of it the flight may draw.
    ///
    /// A frame is taken even when `running` is false — the gap is spent either way. Banking it
    /// instead would just move the jump to whenever the flight resumed, which is the thing this
    /// type exists to prevent.
    @discardableResult
    mutating func frame(at now: Date, running: Bool = true) -> TimeInterval {
        let step = min(Self.maxStep, max(0, now.timeIntervalSince(lastFrame)))
        lastFrame = now

        if running {
            elapsed += step
        }

        return step
    }

    /// Starts a new flight. The curves are all written from t = 0, so this is what makes a fresh
    /// flight — or a bear just put down — begin at the start of one rather than in the middle.
    mutating func restart(at now: Date) {
        elapsed = 0
        lastFrame = now
    }
}
