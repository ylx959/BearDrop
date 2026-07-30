import Foundation

/// Which of the rig's two colour schemes is drawn — the canopy, the text on it, and the bear all
/// follow this one value.
///
/// This is **not** the system appearance. The rig floats over whatever the desktop happens to be
/// and is never behind a window's material, so `.dark`/`.light` here says what the fabric and the
/// fur are made of, not what macOS is set to. The two are independent on purpose: a dark canopy
/// over a light desktop is a perfectly good look, and following the system would take the choice
/// away from whoever wants it.
///
/// Each scheme is the other one inverted. The bear is the reason that has to be stated in hex
/// rather than in `Color`: its art is SVG, and the fills live in a `<style>` block inside the file,
/// so switching schemes means rewriting those declarations on the way in — see
/// `SVGAssetView.recolouring`. Everything the canopy needs is in `CanopyPalette`, keyed off this.
enum RigAppearance: String, CaseIterable, Identifiable, Sendable {
    case dark
    case light

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: "Dark"
        case .light: "Light"
        }
    }

    /// The SF Symbol this scheme is pictured by in the menu.
    var symbolName: String {
        switch self {
        case .dark: "moon.fill"
        case .light: "sun.max.fill"
        }
    }

    var toggled: RigAppearance {
        switch self {
        case .dark: .light
        case .light: .dark
        }
    }

    /// Near-black rather than `#000`, in both schemes. A pure black fill reads as a hole punched in
    /// the screen rather than as an animal, and this is the same blue-black the canopy mixes its
    /// shadows from.
    static let black = "#14161C"
    static let white = "#FFFFFF"

    /// The bear's fur.
    var fur: String {
        switch self {
        case .dark: Self.black
        case .light: Self.white
        }
    }

    /// Everything the bear is read by — the eye, the claws, the muzzle, the belly contour.
    var detail: String {
        switch self {
        case .dark: Self.white
        case .light: Self.black
        }
    }

    /// What to rewrite the bear's SVG `<style>` block to, given that the files on disk are written
    /// in the `.dark` scheme.
    ///
    /// Both entries are needed even for `.dark`, where they are identities: the two schemes *swap*
    /// two colours, so the substitution has to happen in one pass. Applied one after another it
    /// would turn the whole bear a single colour — the first rule paints everything white, and the
    /// second then paints all of that black.
    var bearRecolouring: [String: String] {
        [
            RigAppearance.dark.fur: fur,
            RigAppearance.dark.detail: detail
        ]
    }
}
