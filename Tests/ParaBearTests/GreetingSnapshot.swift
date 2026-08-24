import AppKit
import SwiftUI
import Testing
@testable import ParaBear

/// Renders the rig with the greeting showing, so the bubble's shape and where its tail lands can be
/// judged by eye. None of it is checkable by assertion — `SpeechBubbleTests` can say the outline
/// matches the artwork, but not that the tail points at the bear's mouth.
///
/// Off by default, like `CanopySnapshot`: set `PARABEAR_SNAPSHOT` to a directory to write into.
@MainActor
struct GreetingSnapshot {
    @Test func writeGreetingPNG() throws {
        guard let dir = ProcessInfo.processInfo.environment["PARABEAR_SNAPSHOT"] else { return }

        let settings = SettingsStore()
        settings.animationIntensity = 0
        let viewModel = EventTimelineViewModel(calendarService: CalendarService(), settings: settings)
        viewModel.isExpanded = true

        let scene = ZStack {
            LinearGradient(
                colors: [Color(red: 0.72, green: 0.75, blue: 0.83),
                         Color(red: 0.90, green: 0.86, blue: 0.84)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            BearOverlayView(viewModel: viewModel, settings: settings, driftState: BearDriftState())
        }
        .frame(width: RigLayout.windowSize.width, height: RigLayout.windowSize.height)

        let renderer = ImageRenderer(content: scene)
        renderer.scale = 2
        let image = try #require(renderer.nsImage)
        let tiff = try #require(image.tiffRepresentation)
        let rep = try #require(NSBitmapImageRep(data: tiff))
        let png = try #require(rep.representation(using: .png, properties: [:]))
        try png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("greeting.png"))
    }
}
