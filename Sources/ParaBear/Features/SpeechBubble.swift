import SwiftUI

/// The greeting bubble's outline, traced from the artwork rather than assembled from primitives.
///
/// It was a `RoundedRectangle` with a separate little tail shape parked beside it at a hand-picked
/// offset, and the two were only ever *nearly* joined: the tail's base is a straight chord across
/// the body's edge, so any rounding difference or half-point of drift left a seam where the fill of
/// one met the fill of the other — visible because both are `.regularMaterial`, and a material
/// drawn twice over the same pixels is not the same colour as one drawn once.
///
/// One path has no seam to get wrong. The coordinates are the artwork's own, so the shape can be
/// checked against the file it came from; `SpeechBubbleTests` does exactly that.
struct SpeechBubble: Shape {
    /// The artwork's own box. The body is a true capsule — 579 tall with a 289.5 radius, which is
    /// exactly half — and the tail hangs below it, which is why this is taller than the body.
    static let sourceViewBox = CGSize(width: 2418, height: 837)
    /// How much of that box the capsule occupies. The rest is tail.
    static let bodyShare: CGFloat = 579.0 / 837.0
    /// Where the tail points, as a share of the box. Down and to the right of its own base, so the
    /// bubble hangs above-left of whatever it is pointing at.
    static let tipShare = CGPoint(x: 2169.0 / 2418.0, y: 1.0)

    /// Uniform, off the width — the same rule `ParachuteCanopy` follows, and for the same reason:
    /// scaling x and y separately puts the drawn shape somewhere the measurements below say it is
    /// not.
    static func height(forWidth width: CGFloat) -> CGFloat {
        width * sourceViewBox.height / sourceViewBox.width
    }

    /// The capsule alone, which is the only part text may sit in.
    static func bodyHeight(forWidth width: CGFloat) -> CGFloat {
        height(forWidth: width) * bodyShare
    }

    /// The point the tail aims at, in the bubble's own coordinates.
    ///
    /// A measurement of the artwork, **not** a placement anchor. Placing the bubble by its tip is
    /// the obvious thing and it is wrong — the capsule's right end reaches about a tenth of the
    /// width further right than the tip does, so putting the tip on the bear lays the body across
    /// it. `RigLayout.greetingRect` places by the trailing edge instead.
    static func tailTip(forWidth width: CGFloat) -> CGPoint {
        CGPoint(x: width * tipShare.x, y: height(forWidth: width) * tipShare.y)
    }

    func path(in rect: CGRect) -> Path {
        let scale = rect.width / Self.sourceViewBox.width
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scale, y: rect.minY + y * scale)
        }

        var path = Path()
        // The tail tip, then up its trailing edge to the body.
        path.move(to: point(2169, 837))
        path.addLine(to: point(1911, 579))
        // Along the bottom and round the left end.
        path.addLine(to: point(289.5, 579))
        path.addCurve(
            to: point(0, 289.5),
            control1: point(129.614, 579),
            control2: point(0, 449.386)
        )
        path.addCurve(
            to: point(289.5, 0),
            control1: point(0, 129.614),
            control2: point(129.614, 0)
        )
        // Across the top and round the right end.
        path.addLine(to: point(2128.5, 0))
        path.addCurve(
            to: point(2418, 289.5),
            control1: point(2288.39, 0),
            control2: point(2418, 129.614)
        )
        path.addCurve(
            to: point(2128.5, 579),
            control1: point(2418, 449.386),
            control2: point(2288.39, 579)
        )
        // The short run back to the tail's leading edge, and down to the tip.
        path.addLine(to: point(2122.54, 579))
        path.closeSubpath()

        return path
    }
}
