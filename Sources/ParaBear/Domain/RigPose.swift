import Foundation

/// Where the rig is inside its window at this instant.
///
/// The window needs this for one job: telling a click on the bear from a click on the desktop
/// behind it. Without it the only honest answer is the whole fan the bear could possibly swing
/// through — it hangs from its head and its feet reach 78 points either side, so a box big enough
/// to always contain it is 291 wide for a bear that is 106. That box sat over someone's desktop
/// swallowing clicks the whole time the rig was on screen.
///
/// Knowing the current angle instead makes the region the bear's own outline, which is what was
/// asked for and what it should always have been.
struct RigPose: Equatable {
    /// The in-place drift the whole rig is offset by.
    var drift = CGSize.zero
    /// How far the bear is leaning, about the top of its head.
    var bearDegrees: Double = 0

    static let resting = RigPose()
}
