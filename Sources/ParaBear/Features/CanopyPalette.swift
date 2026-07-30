import SwiftUI

/// What the canopy and the text on it are made of, in each of the rig's two schemes.
///
/// `ParachuteCanopyView` owns *how* the dome is lit — the layers, the blur, the falloffs — and this
/// owns *what colour* each of those layers is. Keeping them apart is what lets the two schemes be
/// read side by side and checked against each other, which matters here because they are not a
/// simple inversion.
///
/// Three things do not invert, and they are the reason this is a table rather than a flag:
///
/// - **The rim and the crown carry the shape on dark; the shading carries it on light.** A dark
///   dome over a bright desktop is a hole until something lights its edge, so on `.dark` the rim
///   and crown are turned well up. On `.light` the fabric is already brighter than most desktops,
///   the silhouette reads on its own, and the same values would blow the crown out to a flat white
///   patch.
/// - **Shadows are darker on light fabric than on dark.** A shadow on near-black fabric has almost
///   no room to go down before it stops being fabric at all.
/// - **The text colours are not the fabric's opposite**, they are what stays legible on it through
///   sheer fabric over an unknown desktop. Hence `textShadow`, which is larger on the light scheme
///   because black type has less to lose against a bright desktop than white type does.
struct CanopyPalette {
    /// The fabric's four stops, crown to hem. The alphas make the canopy sheer, and they thin on
    /// the way down: the hem is the billowing edge and should be the lightest thing on the canopy,
    /// while the crown is where the card's text sits and has to keep enough body to hold type.
    let fabric: [Gradient.Stop]
    /// Every shadow on the canopy is mixed from this. Never a neutral black: a shadow with no hue
    /// in it goes dead, and that is the whole difference between fabric and a hole in the screen.
    let ink: Color
    /// How much of the material behind the fabric shows.
    let sheerness: Double
    /// The strength of the lit edge running round the silhouette, at the point nearest the light.
    let rimStrength: Double
    /// The strength of the broad diffuse crown.
    let crownStrength: Double
    /// How white a gore turned into the light goes, and how deep one turned away from it goes.
    let goreLit: Double
    let goreShaded: Double
    /// How far the fabric darkens as it tucks under at the scallops.
    let hemStrength: Double

    let title: Color
    let subtitle: Color
    let alert: Color
    let urgent: Color
    /// What keeps the type legible when the desktop reaches it through sheer fabric.
    let textShadow: Color
    let textShadowRadius: CGFloat

    static func of(_ appearance: RigAppearance) -> CanopyPalette {
        switch appearance {
        case .dark: dark
        case .light: light
        }
    }

    /// Slate at the crown falling to near-black at the hem. The crown never gets near white: on a
    /// dark canopy the brightest fabric has to stay well below the white text sitting on it, or the
    /// two compete and the words stop being the first thing read.
    static let dark = CanopyPalette(
        fabric: [
            .init(color: Color(red: 0.35, green: 0.37, blue: 0.44).opacity(0.74), location: 0),
            .init(color: Color(red: 0.28, green: 0.30, blue: 0.37).opacity(0.70), location: 0.38),
            .init(color: Color(red: 0.18, green: 0.20, blue: 0.26).opacity(0.64), location: 0.72),
            .init(color: Color(red: 0.11, green: 0.12, blue: 0.17).opacity(0.56), location: 1)
        ],
        ink: Color(red: 0.04, green: 0.05, blue: 0.09),
        sheerness: 0.42,
        rimStrength: 0.46,
        crownStrength: 0.15,
        goreLit: 0.22,
        goreShaded: 0.34,
        hemStrength: 0.34,
        title: .white,
        subtitle: Color(red: 0.78, green: 0.80, blue: 0.85),
        alert: Color(red: 1.00, green: 0.74, blue: 0.44),
        urgent: Color(red: 1.00, green: 0.52, blue: 0.45),
        textShadow: .black.opacity(0.45),
        textShadowRadius: 3.5
    )

    /// Near-white at the crown falling to a cool grey at the hem — the scheme the reference art is
    /// in. It runs slightly denser than the dark one: white fabric has less contrast against a pale
    /// desktop to begin with, and thinning it further leaves nothing for black type to sit on.
    static let light = CanopyPalette(
        fabric: [
            .init(color: Color(red: 1.00, green: 1.00, blue: 1.00).opacity(0.80), location: 0),
            .init(color: Color(red: 0.97, green: 0.98, blue: 0.99).opacity(0.77), location: 0.38),
            .init(color: Color(red: 0.89, green: 0.90, blue: 0.93).opacity(0.71), location: 0.72),
            .init(color: Color(red: 0.79, green: 0.81, blue: 0.86).opacity(0.63), location: 1)
        ],
        ink: Color(red: 0.20, green: 0.23, blue: 0.30),
        sheerness: 0.40,
        rimStrength: 0.90,
        crownStrength: 0.34,
        goreLit: 0.30,
        goreShaded: 0.20,
        hemStrength: 0.24,
        title: Color(red: 0.10, green: 0.11, blue: 0.14),
        subtitle: Color(red: 0.36, green: 0.39, blue: 0.45),
        alert: Color(red: 0.72, green: 0.39, blue: 0.20),
        urgent: Color(red: 0.70, green: 0.19, blue: 0.15),
        textShadow: .white.opacity(0.55),
        textShadowRadius: 2.5
    )
}
