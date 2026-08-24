import CoreGraphics
import SwiftUI
import Testing

/// Renders a view and answers, per pixel, whether anything solid was drawn there.
///
/// Two tests measure a hand-written region against the artwork it is supposed to cover —
/// `OverlayHitTestingTests` checks the click region holds every pixel of the rig, and
/// `BearTapTargetTests` checks every pixel of the bear can be clicked. Both need the same thing:
/// the drawn alpha at a point. It is stated once because the interesting number is shared and easy
/// to get subtly wrong in two places — see `solidAlpha`.
struct SolidPixels {
    /// Both rigs carry a soft drop shadow that spreads well past the artwork. A shadow is not a
    /// thing anyone aims at or grabs, so only what is solidly drawn counts.
    static let solidAlpha: UInt8 = 160

    let width: Int
    let height: Int
    private let pixels: [UInt8]

    @MainActor
    init<V: View>(of view: V) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1

        let image = try #require(renderer.cgImage)
        width = image.width
        height = image.height

        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let context = try #require(
            CGContext(
                data: &buffer,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        pixels = buffer
    }

    func isSolid(column: Int, row: Int) -> Bool {
        pixels[(row * width + column) * 4 + 3] > Self.solidAlpha
    }

    /// The centre of the pixel, which is the point a region should be asked about.
    func centre(column: Int, row: Int) -> CGPoint {
        CGPoint(x: Double(column) + 0.5, y: Double(row) + 0.5)
    }

    func forEachPixel(_ body: (Int, Int) -> Void) {
        for row in 0..<height {
            for column in 0..<width {
                body(column, row)
            }
        }
    }
}
