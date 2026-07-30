import SwiftUI

/// The canopy of `parachute.svg`, redrawn as a shape so it can be lit rather than pasted.
///
/// The artwork draws the canopy as one flat white fill with a baked-in raster shadow underneath,
/// which is exactly why it reads as a sticker: nothing about it responds to where the light is or
/// to the fact that the fabric is a dome made of six panels. Here it is the same outline, but split
/// into the parts a light can be aimed at — `panel(_:in:)` for the fabric between two lines,
/// `seam(_:in:)` for the fold where two panels meet.
///
/// Every coordinate below is the artwork's own, in the artwork's coordinate space, so it can be
/// checked against the file directly — `hemGather` is the single exception, and says why. That is
/// also what keeps this shape and `RiggingLines` in
/// agreement: both place the artwork's coordinates the same way, so the hem the fabric ends at and
/// the hem the lines hang from are the one hem.
struct ParachuteCanopy: Shape {
    /// The region of `parachute.svg` this shape stands in for. It shares its left edge and its width
    /// with `RiggingLines.sourceRect` — that is what makes the two views line up — and stops at the
    /// hem, so the bottom of this view *is* the hem.
    static let sourceRect = CGRect(
        x: RiggingLines.sourceRect.minX,
        y: 370,
        width: RiggingLines.sourceRect.width,
        height: RiggingLines.hemY - 370
    )

    /// The top of the dome, from the artwork's path.
    static let apex = CGPoint(x: 490.25, y: 381.23)
    /// The curve running from the apex down to the left end of the hem, as its (first, second)
    /// control point read apex-outwards. Half of the artwork's silhouette.
    static let leftShoulder = (CGPoint(x: 365.94, y: 381.23), CGPoint(x: 265.07, y: 471.35))
    /// The same curve on the right. The artwork writes it as a smooth continuation of the left one,
    /// so its first control point is the reflection of the left one's second about the apex.
    static let rightShoulder = (CGPoint(x: 614.56, y: 381.23), CGPoint(x: 715.41, y: 471.3))

    /// How far the fabric lifts off the hem between two suspension lines: the lines pull their own
    /// points down, and everything in between billows up. From the artwork's scallops.
    static let cuspLift: Double = 47.53
    /// How far either side of a billow's high point its controls reach across, and how far the
    /// fabric has already lifted at the control leaving a line. Also the artwork's own.
    static let cuspShoulder: Double = 20.79
    static let hemShoulder: Double = 26.25
    /// How far sideways the fabric splays as it leaves a line.
    ///
    /// The artwork leaves each hem point straight up on *both* sides, so the two billows either side
    /// of a line meet in a cusp of no width at all: 10 units above the hem the fabric is under one
    /// unit across, which at the size this is drawn is less than half a pixel. The five inner lines
    /// then hang from a point where nothing is drawn, and read as hanging free below the canopy —
    /// only the outermost pair look attached, because there the silhouette arrives at a real angle.
    ///
    /// A canopy is gathered at each line, not slit to a razor's edge, so the fabric comes down into
    /// every line as a visible tab. This is the width of that tab, and the one place the shape
    /// departs from the artwork's own hem.
    static let hemGather: Double = 12

    static var lineCount: Int { RiggingLines.lineCount }
    /// One panel of fabric between each neighbouring pair of lines.
    static var panelCount: Int { lineCount - 1 }
    static var hemSpan: Double { RiggingLines.lastHemX - RiggingLines.firstHemX }

    /// The height this shape wants at a given width — the crop's own proportions, so nothing of the
    /// hem is cut off.
    static func height(forWidth width: CGFloat) -> CGFloat {
        width * sourceRect.height / sourceRect.width
    }

    /// The artwork's coordinates, placed in the rect this view is drawn in.
    static func place(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        let scale = rect.width / sourceRect.width
        return CGPoint(
            x: rect.minX + (point.x - sourceRect.minX) * scale,
            y: rect.minY + (point.y - sourceRect.minY) * scale
        )
    }

    /// Where the `index`th suspension line meets the fabric.
    static func hemPoint(_ index: Int, in rect: CGRect) -> CGPoint {
        let across = Double(index) / Double(lineCount - 1)
        return place(
            CGPoint(x: RiggingLines.firstHemX + hemSpan * across, y: RiggingLines.hemY),
            in: rect
        )
    }

    /// The seam running from the apex down to the `index`th point of the hem.
    ///
    /// The outermost seam on either side *is* the artwork's silhouette, so every seam in between is
    /// read off that same pair of curves: sliding their control points across from the left
    /// silhouette to the right one carries the dome's curvature along with them, and hands the
    /// middle seam — which has nowhere to curve to — the straight drop it should have.
    static func seam(_ index: Int, in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: place(apex, in: rect))
        appendSeam(index, to: &path, in: rect)
        return path
    }

    /// The fabric between the `index`th line and the next one along: two seams and the billow of
    /// hem between them.
    static func panel(_ index: Int, in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: place(apex, in: rect))
        appendSeam(index, to: &path, in: rect)
        appendScallop(index, to: &path, in: rect)
        appendSeam(index + 1, reversed: true, to: &path, in: rect)
        path.closeSubpath()
        return path
    }

    /// The silhouette: along the whole scalloped hem, then back over the dome.
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: Self.hemPoint(0, in: rect))

        for panel in 0..<Self.panelCount {
            Self.appendScallop(panel, to: &path, in: rect)
        }

        Self.appendSeam(Self.lineCount - 1, reversed: true, to: &path, in: rect)
        Self.appendSeam(0, to: &path, in: rect)
        path.closeSubpath()

        return path
    }

    // MARK: - Pieces

    /// The seam's two control points, slid `across` from the left silhouette to the right one.
    private static func seamControls(_ index: Int) -> (CGPoint, CGPoint) {
        let across = Double(index) / Double(lineCount - 1)
        return (
            between(leftShoulder.0, rightShoulder.0, across),
            between(leftShoulder.1, rightShoulder.1, across)
        )
    }

    /// Continues `path` from the apex down to the hem, or from the hem back up to the apex.
    private static func appendSeam(
        _ index: Int,
        reversed: Bool = false,
        to path: inout Path,
        in rect: CGRect
    ) {
        let (first, second) = seamControls(index)

        if reversed {
            path.addCurve(
                to: place(apex, in: rect),
                control1: place(second, in: rect),
                control2: place(first, in: rect)
            )
        } else {
            path.addCurve(
                to: hemPoint(index, in: rect),
                control1: place(first, in: rect),
                control2: place(second, in: rect)
            )
        }
    }

    /// Continues `path` along one billow of the hem, from the `index`th line to the next.
    private static func appendScallop(_ index: Int, to path: inout Path, in rect: CGRect) {
        let start = CGPoint(
            x: RiggingLines.firstHemX + hemSpan * Double(index) / Double(panelCount),
            y: RiggingLines.hemY
        )
        let end = CGPoint(x: start.x + hemSpan / Double(panelCount), y: RiggingLines.hemY)
        let cusp = CGPoint(x: (start.x + end.x) / 2, y: RiggingLines.hemY - cuspLift)

        path.addCurve(
            to: place(cusp, in: rect),
            control1: place(
                CGPoint(x: start.x + hemGather, y: RiggingLines.hemY - hemShoulder),
                in: rect
            ),
            control2: place(CGPoint(x: cusp.x - cuspShoulder, y: cusp.y), in: rect)
        )
        path.addCurve(
            to: place(end, in: rect),
            control1: place(CGPoint(x: cusp.x + cuspShoulder, y: cusp.y), in: rect),
            control2: place(
                CGPoint(x: end.x - hemGather, y: RiggingLines.hemY - hemShoulder),
                in: rect
            )
        )
    }

    private static func between(_ start: CGPoint, _ end: CGPoint, _ fraction: Double) -> CGPoint {
        CGPoint(
            x: start.x + (end.x - start.x) * fraction,
            y: start.y + (end.y - start.y) * fraction
        )
    }
}
