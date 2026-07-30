import AppKit
import SwiftUI
import Testing
@testable import ParaBear

/// Renders the canopy to a PNG so the look can be judged by eye rather than by numbers.
///
/// Off by default: set `PARABEAR_SNAPSHOT` to a directory to write into. `.ultraThinMaterial` has
/// no backdrop inside `ImageRenderer`, so what comes out is the canopy's own paint with nothing
/// behind it — which is the part being judged.
@MainActor
struct CanopySnapshot {
    @Test func writesCanopyPNG() throws {
        guard let directory = ProcessInfo.processInfo.environment["PARABEAR_SNAPSHOT"] else {
            return
        }

        for appearance in RigAppearance.allCases {
            try write(appearance, into: directory)
        }
    }

    private func write(_ appearance: RigAppearance, into directory: String) throws {
        let width = ParachuteEventCard.width
        let height = ParachuteCanopy.height(forWidth: width)

        let scene = ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.72, green: 0.75, blue: 0.83),
                    Color(red: 0.90, green: 0.86, blue: 0.84),
                    Color(red: 0.78, green: 0.80, blue: 0.86)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // The rig as `BearOverlayView` stacks it, minus the motion: card, lines, bear, pulled
            // together by the same two negative spacings.
            VStack(spacing: -RiggingLines.bearOverlap) {
                VStack(spacing: -RiggingLines.hemOverlap(forWidth: width)) {
                    ParachuteEventCard(
                        event: nil,
                        countdownText: "in 12 min",
                        authorizationState: .authorized,
                        mood: .alert,
                        appearance: appearance
                    )
                    .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 10)

                    RiggingLines()
                        .stroke(
                            .secondary.opacity(0.46),
                            style: StrokeStyle(lineWidth: RiggingLines.lineWidth, lineCap: .round)
                        )
                        .frame(width: width, height: 118)
                }

                BearCharacterView(mood: .alert, appearance: appearance)
                    .frame(width: 106, height: 192)
            }
        }
        .frame(width: width + 120, height: height + 380)

        let renderer = ImageRenderer(content: scene)
        renderer.scale = 3

        let image = try #require(renderer.nsImage)
        let data = try #require(image.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data: data))
        let png = try #require(bitmap.representation(using: .png, properties: [:]))

        try png.write(
            to: URL(fileURLWithPath: directory)
                .appendingPathComponent("canopy-\(appearance.rawValue).png")
        )
    }
}
