import SwiftUI

/// The canopy as a solid dome of fabric, lit from one side — an object made of light, rather than a
/// pane you look through.
///
/// It used to be the other way round: near-clear glass in the middle with everything glassy
/// happening at the rim, painted fringes and all. That reads as *glass*, and a parachute is fabric.
/// The reference this is built to is the shape you see on an Apple product icon — matte, soft
/// everywhere, with all of the depth coming from one light rolling off a curved surface. Nothing
/// here is a hard line.
///
/// Three things carry the fabric, and they all answer to `CanopyLighting`:
///
/// - `fabric` — the body. Bright at the crown, cooling and darkening into the hem, which is what
///   says the surface is turning away from you as it comes down.
/// - `gores` — the panel tones, deliberately **blurred** into each other. The panels meet along
///   hard vector edges; a dome has no facets, so the shading is drawn per panel and then smeared
///   across the joins until only the bands survive.
/// - `hemShade` — the fabric tucking under at the scallops, where no light reaches.
///
/// The apex stays closed. A vent there is what a real canopy has, and it would give the dome a
/// piece of true depth — but on a shape this squat it lands as a dark spot in the middle of the
/// card, right where the eye goes first, and it was not wanted. So nothing is drawn at the point
/// where all six folds converge, and the seams fade out into it instead.
///
/// The fabric is **sheer**, and the material behind it rises and falls with the fabric's own alpha:
/// thin fabric with nothing behind it is a tinted film over the desktop, and the material is what
/// puts something *there* — a frosted layer the desktop arrives through softened, which is what the
/// eye reads as cloth rather than as a filter.
///
/// Every colour comes from `CanopyPalette`, which is where the two schemes are stated side by side
/// and why they are not a plain inversion of one another. The layer that carries the shape changes
/// with the scheme: on `.dark`, a dark shape over a bright desktop is a *hole* until something
/// lights its edge, so `rimLight` and `crownLight` do the reading and the shading fills in behind
/// them; on `.light` the silhouette holds on its own and the shading leads.
///
/// `crownLight` is the one reversal from the glass version, which deliberately had no highlight. A
/// bright *spot* on glass is a light source that fails to move when anything else does. `crownLight`
/// is a broad diffuse falloff sized to a third of the canopy: it is the shading, not a reflection,
/// and without it the fabric flattens.
struct ParachuteCanopyView: View {
    var appearance: RigAppearance = .dark

    private static let light = CanopyLighting.standard

    /// How much of the colour coming through the fabric to keep, so a pale desktop still arrives as
    /// colour rather than grey.
    private static let saturation = 1.25
    /// How far the panel tones are smeared across the joins between panels, as a fraction of the
    /// canopy's width. This is the single knob deciding whether the canopy reads as a dome or as a
    /// folded paper fan.
    private static let goreSoftness = 0.028

    private var palette: CanopyPalette { CanopyPalette.of(appearance) }

    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size)

            ZStack {
                ParachuteCanopy()
                    .fill(.ultraThinMaterial)
                    .saturation(Self.saturation)
                    .opacity(palette.sheerness)

                ParachuteCanopy().fill(fabric)

                gores(in: rect)
                seams(in: rect)
                hemShade(in: rect)
                crownLight(in: rect)

                ParachuteCanopy().stroke(rimLight, lineWidth: 0.8)
            }
            .compositingGroup()
        }
    }

    // MARK: - The fabric

    private var fabric: LinearGradient {
        LinearGradient(stops: palette.fabric, startPoint: .top, endPoint: .bottom)
    }

    /// The lit edge of the silhouette.
    ///
    /// It falls away fast. The stroke follows the whole silhouette, scallops included, and the
    /// scallops are the part of the outline furthest from the light — held up, they read as the hem
    /// being lit from underneath, which is a second light source nothing else in the scene has.
    private var rimLight: LinearGradient {
        let strength = palette.rimStrength

        return LinearGradient(
            stops: [
                .init(color: .white.opacity(strength), location: 0),
                .init(color: .white.opacity(strength * 0.35), location: 0.26),
                .init(color: .white.opacity(strength * 0.09), location: 0.6),
                .init(color: .white.opacity(strength * 0.05), location: 1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - The gores

    /// Each panel takes as much light as the angle it faces allows, and then the whole set is
    /// blurred: the panels are drawn from hard vector edges, and a dome has no facets. What survives
    /// the blur is a set of soft bands running down the fabric, which is what a gored canopy
    /// actually looks like.
    private func gores(in rect: CGRect) -> some View {
        ZStack {
            ForEach(0..<ParachuteCanopy.panelCount, id: \.self) { panel in
                ParachuteCanopy.panel(panel, in: rect)
                    .fill(goreShade(panel))
            }
        }
        .blur(radius: rect.width * Self.goreSoftness)
        .mask(ParachuteCanopy().fill(.white))
    }

    private func goreShade(_ panel: Int) -> LinearGradient {
        let tone = Self.light.tone(panel: panel)
        let away = max(-tone, 0)
        let towards = max(tone, 0)
        let grazing = Self.light.grazing(panel: panel)

        return LinearGradient(
            colors: [
                .white.opacity(palette.goreLit * towards),
                palette.ink.opacity(
                    0.05 + palette.goreShaded * away + palette.goreShaded * 0.76 * grazing
                )
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// The crown, where the fabric faces the light most directly. Broad — a third of the canopy —
    /// and centred on the light's own position, so nudging `CanopyLighting` moves it along with
    /// every other layer.
    private func crownLight(in rect: CGRect) -> some View {
        RadialGradient(
            colors: [.white.opacity(palette.crownStrength), .white.opacity(0)],
            center: UnitPoint(x: Self.crownAcross, y: Self.crownDown),
            startRadius: 0,
            endRadius: rect.width * 0.34
        )
        .mask(ParachuteCanopy().fill(.white))
    }

    /// Where the light sits, in this view's own coordinates — the light is stated across the hem,
    /// and the hem is inset from the crop's edges.
    private static let crownAcross: CGFloat = {
        let x = RiggingLines.firstHemX + ParachuteCanopy.hemSpan * light.position
        return (x - ParachuteCanopy.sourceRect.minX) / ParachuteCanopy.sourceRect.width
    }()

    /// A third of the way down from the apex: high on the dome, and clear of the text below.
    private static let crownDown: CGFloat = {
        let apex = ParachuteCanopy.apex.y
        let y = apex + (RiggingLines.hemY - apex) * 0.34
        return (y - ParachuteCanopy.sourceRect.minY) / ParachuteCanopy.sourceRect.height
    }()

    // MARK: - The hem

    /// The fabric tucking under at each scallop. Masked by the canopy, so every billow darkens into
    /// its own lowest points rather than the whole bottom edge going grey in a straight line.
    private func hemShade(in rect: CGRect) -> some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.52),
                .init(color: palette.ink.opacity(palette.hemStrength * 0.41), location: 0.82),
                .init(color: palette.ink.opacity(palette.hemStrength), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .mask(ParachuteCanopy().fill(.white))
    }

    // MARK: - The folds

    /// The creases where two panels meet. After the gore blur these are all that is left of the
    /// joins, so they are drawn back in — but faint, and fading out towards the crown where the
    /// panels are seen face-on and a fold has nothing to catch.
    private func seams(in rect: CGRect) -> some View {
        let offset = max(rect.width * 0.004, 0.5)

        return ForEach(1..<ParachuteCanopy.lineCount - 1, id: \.self) { index in
            let seam = ParachuteCanopy.seam(index, in: rect)
            let onTheLeft = Self.light.foldCatchesLightOnTheLeft(
                line: index,
                of: ParachuteCanopy.lineCount
            )
            let towardsLight: CGFloat = onTheLeft ? -offset : offset

            ZStack {
                seam.stroke(seamShadow, style: Self.seamStroke)
                seam.stroke(seamHighlight, style: Self.seamStroke)
                    .offset(x: towardsLight)
            }
            .blur(radius: 0.7)
        }
    }

    private static let seamStroke = StrokeStyle(lineWidth: 0.9, lineCap: .round)

    private var seamShadow: LinearGradient {
        LinearGradient(
            colors: [
                palette.ink.opacity(palette.goreShaded * 0.06),
                palette.ink.opacity(palette.goreShaded * 0.59)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var seamHighlight: LinearGradient {
        LinearGradient(
            colors: [
                .white.opacity(palette.goreLit * 0.09),
                .white.opacity(palette.goreLit * 0.73)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
