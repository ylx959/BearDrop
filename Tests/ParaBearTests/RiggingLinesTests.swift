import CoreGraphics
import Testing
@testable import ParaBear

struct RiggingLinesTests {
    private static let frame = CGRect(x: 0, y: 0, width: 244, height: 118)

    private struct Rig {
        var lines: [(top: CGPoint, knot: CGPoint, control: CGPoint)] = []
        var riser: (top: CGPoint, bottom: CGPoint)?
    }

    private static func rig(in rect: CGRect = frame) -> Rig {
        var rig = Rig()
        var pending: CGPoint?

        RiggingLines().path(in: rect).forEach { element in
            switch element {
            case let .move(to: point):
                pending = point
            case let .quadCurve(to: point, control: control):
                if let start = pending { rig.lines.append((start, point, control)) }
                pending = point
            case let .line(to: point):
                if let start = pending { rig.riser = (start, point) }
                pending = point
            default:
                break
            }
        }

        return rig
    }

    // MARK: - The fan

    @Test func thereIsALineForEveryPointOnTheCanopy() {
        #expect(Self.rig().lines.count == RiggingLines.lineCount)
    }

    /// The point of the change: the outer pair used to be the only ones with anything hanging from
    /// them, so the tops must be evenly spread across the hem rather than bunched at the edges.
    @Test func theLinesStartEvenlySpacedAlongTheHem() {
        let tops = Self.rig().lines.map(\.top.x)
        let gaps = zip(tops, tops.dropFirst()).map { $1 - $0 }

        #expect(tops == tops.sorted())
        for gap in gaps {
            #expect(abs(gap - gaps[0]) < 0.001)
        }
    }

    @Test func everyLineEndsAtTheSameKnot() {
        let knots = Self.rig().lines.map(\.knot)

        for knot in knots.dropFirst() {
            #expect(abs(knot.x - knots[0].x) < 0.001)
            #expect(abs(knot.y - knots[0].y) < 0.001)
        }
    }

    @Test func theFanAndItsKnotStayInsideTheFrame() {
        for line in Self.rig().lines {
            #expect(Self.frame.contains(line.top))
            #expect(Self.frame.contains(line.knot))
        }
    }

    /// The middle line runs straight down, because the artwork's knot sits directly under the
    /// middle point of the hem. If this drifts, the fan has gone lopsided.
    @Test func theMiddleLineHangsStraightDown() {
        let lines = Self.rig().lines
        let middle = lines[lines.count / 2]

        #expect(abs(middle.top.x - middle.knot.x) < 0.5)
        #expect(middle.knot.y > middle.top.y)
    }

    @Test func theFanScalesWithTheFrameItIsDrawnIn() {
        let doubled = Self.rig(in: CGRect(x: 0, y: 0, width: 488, height: 236)).lines
        let normal = Self.rig().lines

        #expect(doubled.count == normal.count)
        #expect(abs(doubled[0].top.x - normal[0].top.x * 2) < 0.001)
        #expect(abs(doubled[0].knot.y - normal[0].knot.y * 2) < 0.001)
    }

    // MARK: - The bow

    /// Every line bows up off its chord — none of them is a bare straight line except the middle
    /// one, which has nowhere to bow to.
    @Test func theLinesBowUpOffTheirChords() {
        let lines = Self.rig().lines

        for line in lines {
            let chordMidY = (line.top.y + line.knot.y) / 2
            let travelsSideways = abs(line.top.x - line.knot.x) > 1

            if travelsSideways {
                #expect(line.control.y < chordMidY)
            } else {
                #expect(abs(line.control.y - chordMidY) < 0.001)
            }
        }
    }

    /// Slightly curved, not slack: the sag stays in the same league as the artwork's own two lines,
    /// which bow about 3% of their chord.
    @Test func theBowIsGentle() {
        for line in Self.rig().lines {
            let chord = (
                x: line.knot.x - line.top.x,
                y: line.knot.y - line.top.y
            )
            let chordLength = (chord.x * chord.x + chord.y * chord.y).squareRoot()
            // A quadratic curve reaches half the way to its control point at the midpoint.
            let sag = abs(line.control.y - (line.top.y + line.knot.y) / 2) / 2

            #expect(sag / chordLength < 0.08)
        }
    }

    /// The outermost line reaches furthest across, so it bows the most; the fan should open out
    /// rather than every line curving by the same flat amount.
    @Test func theOuterLinesBowMoreThanTheInnerOnes() {
        let lines = Self.rig().lines
        let sag = { (line: (top: CGPoint, knot: CGPoint, control: CGPoint)) in
            abs(line.control.y - (line.top.y + line.knot.y) / 2)
        }

        #expect(sag(lines[0]) > sag(lines[1]))
        #expect(sag(lines[1]) > sag(lines[2]))
    }

    // MARK: - The riser

    /// This is the bit that went missing when the artwork stopped being used directly: the single
    /// line carrying on below the knot onto the bear's head.
    @Test func aRiserCarriesOnBelowTheKnotOntoTheBear() throws {
        let rig = Self.rig()
        let riser = try #require(rig.riser)
        let knot = try #require(rig.lines.first?.knot)

        #expect(abs(riser.top.x - knot.x) < 0.001)
        #expect(abs(riser.top.y - knot.y) < 0.001)
        #expect(abs(riser.bottom.x - riser.top.x) < 0.001)
        // Into the band the bear's frame is pulled up over, so the line reaches the head and no gap
        // opens between the two.
        #expect(riser.bottom.y > Self.frame.maxY - RiggingLines.bearOverlap)
    }

    /// The bear swings independently of the canopy, so the head only reliably covers the riser near
    /// its own crown. A riser reaching the whole way down is hidden only while the two are lined up,
    /// and swings clear as a stray thread as soon as the rig is shaken about.
    @Test func theRiserStopsWhereTheBearCanStillCoverIt() throws {
        let riser = try #require(Self.rig().riser)

        #expect(riser.bottom.y < Self.frame.maxY)
    }
}
