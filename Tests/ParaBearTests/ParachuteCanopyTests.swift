import CoreGraphics
import SwiftUI
import Testing
@testable import ParaBear

struct ParachuteCanopyTests {
    private static let frame = CGRect(
        x: 0,
        y: 0,
        width: 244,
        height: ParachuteCanopy.height(forWidth: 244)
    )

    private static func points(of path: Path) -> [CGPoint] {
        var points: [CGPoint] = []

        path.forEach { element in
            switch element {
            case let .move(to: point), let .line(to: point):
                points.append(point)
            case let .quadCurve(to: point, control: _):
                points.append(point)
            case let .curve(to: point, control1: _, control2: _):
                points.append(point)
            case .closeSubpath:
                break
            }
        }

        return points
    }

    // MARK: - The hem

    /// The whole reason this shape exists rather than the artwork being pasted in: the fabric has to
    /// end where the lines begin. Both views place the artwork's coordinates from the same crop, so
    /// a line's top and the hem point it hangs from share an x whatever width they are drawn at.
    @Test func theHemLandsWhereTheSuspensionLinesStart() {
        let lines = RiggingLines().path(in: CGRect(x: 0, y: 0, width: 244, height: 118))
        var tops: [CGPoint] = []
        lines.forEach { element in
            if case let .move(to: point) = element { tops.append(point) }
        }

        for index in 0..<ParachuteCanopy.lineCount {
            #expect(abs(ParachuteCanopy.hemPoint(index, in: Self.frame).x - tops[index].x) < 0.001)
        }
    }

    /// The bottom edge of the view is the hem, so nothing of the scalloped edge is cut off.
    @Test func theHemSitsOnTheBottomEdgeOfTheView() {
        for index in 0..<ParachuteCanopy.lineCount {
            #expect(abs(ParachuteCanopy.hemPoint(index, in: Self.frame).y - Self.frame.maxY) < 0.001)
        }
    }

    /// A line has to come out of fabric. The artwork's hem meets each line as a cusp of no width at
    /// all, so the five inner lines hung from a point where nothing was drawn and read as floating
    /// below the canopy; `hemGather` gives every one of them a tab to hang from.
    @Test func thereIsFabricAtEveryPointALineHangsFrom() {
        let edge = Self.samples(of: ParachuteCanopy().path(in: Self.frame), count: 8000)
        let height: CGFloat = 3

        for index in 0..<ParachuteCanopy.lineCount {
            let hem = ParachuteCanopy.hemPoint(index, in: Self.frame)
            // Only the two edges meeting at this line, not the ones over the neighbouring billows.
            let across = edge
                .filter { abs($0.y - (hem.y - height)) < 0.25 && abs($0.x - hem.x) < 10 }
                .map { $0.x }

            #expect((across.max() ?? 0) - (across.min() ?? 0) > 1)
        }
    }

    @Test func theFabricBillowsUpBetweenEveryPairOfLines() {
        let hem = Self.points(of: ParachuteCanopy().path(in: Self.frame))
        let lifted = hem.filter { $0.y < Self.frame.maxY - 1 && $0.y > Self.frame.midY }

        // One high point per panel, plus the apex end of each silhouette curve.
        #expect(lifted.count == ParachuteCanopy.panelCount)
    }

    // MARK: - The seams

    @Test func thereIsASeamForEveryLine() {
        for index in 0..<ParachuteCanopy.lineCount {
            let seam = Self.points(of: ParachuteCanopy.seam(index, in: Self.frame))

            #expect(seam.count == 2)
            #expect(abs(seam[0].x - ParachuteCanopy.place(ParachuteCanopy.apex, in: Self.frame).x) < 0.001)
            #expect(abs(seam[1].x - ParachuteCanopy.hemPoint(index, in: Self.frame).x) < 0.001)
        }
    }

    /// The middle seam has nowhere to curve to: it drops straight from the apex, which sits directly
    /// over the middle of the hem.
    @Test func theMiddleSeamDropsStraight() {
        let middle = ParachuteCanopy.lineCount / 2
        var controls: [CGPoint] = []

        ParachuteCanopy.seam(middle, in: Self.frame).forEach { element in
            if case let .curve(to: _, control1: first, control2: second) = element {
                controls = [first, second]
            }
        }

        let apex = ParachuteCanopy.place(ParachuteCanopy.apex, in: Self.frame)
        for control in controls {
            #expect(abs(control.x - apex.x) < 0.5)
        }
    }

    /// The outermost seams are the silhouette itself — if they drift off it, the end panels grow a
    /// sliver of fabric outside the canopy.
    @Test func theOutermostSeamsRunAlongTheSilhouette() {
        // Densely enough that the gap measured below is the seam leaving the edge, not the spacing
        // between samples of it.
        let edge = Self.samples(of: ParachuteCanopy().path(in: Self.frame), count: 4000)

        for index in [0, ParachuteCanopy.lineCount - 1] {
            for point in Self.samples(of: ParachuteCanopy.seam(index, in: Self.frame), count: 20) {
                let gap = edge
                    .map { hypot($0.x - point.x, $0.y - point.y) }
                    .min() ?? .infinity

                #expect(gap < 0.5)
            }
        }
    }

    private static func samples(of path: Path, count: Int) -> [CGPoint] {
        (0...count).compactMap { step in
            path.trimmedPath(from: 0, to: CGFloat(step) / CGFloat(count)).currentPoint
        }
    }

    // MARK: - The panels

    @Test func thePanelsShareTheirSeamsWithTheirNeighbours() {
        for index in 0..<(ParachuteCanopy.panelCount - 1) {
            let panel = Self.points(of: ParachuteCanopy.panel(index, in: Self.frame))
            let next = Self.points(of: ParachuteCanopy.panel(index + 1, in: Self.frame))

            // Every panel starts at the apex, runs down its left seam to the hem, across the billow
            // to the next line, and back up to the apex.
            #expect(abs(panel[1].x - ParachuteCanopy.hemPoint(index, in: Self.frame).x) < 0.001)
            #expect(abs(panel[3].x - next[1].x) < 0.001)
            #expect(abs(panel[3].y - next[1].y) < 0.001)
        }
    }

    @Test func thePanelsStayInsideTheCanopy() {
        let silhouette = ParachuteCanopy().path(in: Self.frame)

        for index in 0..<ParachuteCanopy.panelCount {
            let panel = ParachuteCanopy.panel(index, in: Self.frame)
            #expect(silhouette.boundingRect.insetBy(dx: -0.5, dy: -0.5).contains(panel.boundingRect))
        }
    }

    @Test func theCanopyScalesWithTheFrameItIsDrawnIn() {
        let doubled = CGRect(x: 0, y: 0, width: 488, height: ParachuteCanopy.height(forWidth: 488))
        let normal = ParachuteCanopy().path(in: Self.frame).boundingRect
        let large = ParachuteCanopy().path(in: doubled).boundingRect

        #expect(abs(large.width - normal.width * 2) < 0.001)
        #expect(abs(large.height - normal.height * 2) < 0.001)
    }

}

struct CanopyLightingTests {
    private static let light = CanopyLighting.standard
    private static var tones: [Double] {
        (0..<light.panelCount).map { light.tone(panel: $0) }
    }

    /// One light: the shading sweeps across the canopy once, rising to the panel facing the light
    /// and falling away after it. A second bright patch would read as a second lamp.
    @Test func thePanelsShadeAwayFromTheLight() {
        let tones = Self.tones
        let brightest = tones.firstIndex(of: tones.max()!)!

        for index in stride(from: brightest, to: 0, by: -1) {
            #expect(tones[index] > tones[index - 1])
        }
        for index in (brightest + 1)..<tones.count {
            #expect(tones[index] < tones[index - 1])
        }
    }

    /// The light is left of centre, so the far right of the canopy is the part turned away from it.
    @Test func theFarSideOfTheCanopyIsInShadow() {
        #expect(Self.tones.first! > 0)
        #expect(Self.tones.last! < 0)
    }

    /// Both ends of the hem are seen edge-on, the middle of the canopy square-on.
    @Test func theEndsOfTheCanopyAreSeenMostEdgeOn() {
        let grazing = (0..<Self.light.panelCount).map { Self.light.grazing(panel: $0) }

        #expect(grazing.first! > grazing[1])
        #expect(grazing.last! > grazing[grazing.count - 2])
        #expect(grazing.min()! == grazing[grazing.count / 2 - 1] || grazing.min()! == grazing[grazing.count / 2])
    }

    /// Every fold turns its lit side towards the light, so no seam is lit from the wrong side.
    @Test func theFoldsCatchTheLightOnTheSideFacingIt() {
        let lineCount = ParachuteCanopy.lineCount

        for line in 0..<lineCount {
            let across = Double(line) / Double(lineCount - 1)
            #expect(
                Self.light.foldCatchesLightOnTheLeft(line: line, of: lineCount)
                    == (across < Self.light.position)
            )
        }
    }
}
