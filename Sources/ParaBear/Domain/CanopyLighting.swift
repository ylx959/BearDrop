import Foundation

/// One light on the canopy, and what each panel of fabric makes of it.
///
/// The canopy is drawn flat, so shading is the only thing that can say a panel is turned away.
/// Reading the whole dome as a half turn — the left end of the hem facing hard left, the right end
/// hard right — gives every panel a direction to face, and each one then takes as much light as the
/// angle between it and the light allows.
///
/// Stated once, and used for every layer that answers to the light: the panels' tones, the side of
/// each seam that catches the light, and where the highlight sits. A tone hand-picked per panel
/// would drift out of agreement with the highlight the moment either was nudged.
struct CanopyLighting {
    /// Where the light sits across the canopy: 0 is the left end of the hem, 1 the right. Slightly
    /// left of centre, which is where the rest of the app casts its shadows from.
    let position: Double
    let panelCount: Int

    static let standard = CanopyLighting(position: 0.31, panelCount: ParachuteCanopy.panelCount)

    /// How far across the canopy the middle of the `panel`th panel sits.
    func across(panel: Int) -> Double {
        (Double(panel) + 0.5) / Double(panelCount)
    }

    /// How much light a panel catches: −1 facing straight away from the light, 1 straight into it.
    func tone(panel: Int) -> Double {
        cos((across(panel: panel) - position) * .pi)
    }

    /// How edge-on a panel is seen — 0 in the middle of the canopy, 1 at either end, where even a
    /// lit surface goes dark.
    func grazing(panel: Int) -> Double {
        pow(abs(across(panel: panel) - 0.5) * 2, 2)
    }

    /// Whether the lit side of the fold at `line` is its left side.
    func foldCatchesLightOnTheLeft(line: Int, of lineCount: Int) -> Bool {
        Double(line) / Double(lineCount - 1) < position
    }
}
