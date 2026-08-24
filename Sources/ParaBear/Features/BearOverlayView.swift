import AppKit
import SwiftUI

struct BearOverlayView: View {
    @ObservedObject var viewModel: EventTimelineViewModel
    @ObservedObject var settings: SettingsStore
    let driftState: BearDriftState

    private let animationStart = Date()
    private let windSeed = Double.random(in: 0...10_000)

    var body: some View {
        ZStack(alignment: .topLeading) {
            TimelineView(.animation) { timeline in
                let motion = WindSwayMotion.sample(
                    elapsed: timeline.date.timeIntervalSince(animationStart),
                    mood: viewModel.mood,
                    intensity: settings.animationIntensity,
                    windStyle: settings.windStyle,
                    seed: windSeed,
                    alongside: driftState.descentTravel
                )
                // Reported back so the window knows where the rig actually is, and can let clicks
                // through everywhere it is not. Written here because this is the one place that
                // knows: the pose is a function of the timeline's own instant.
                let _ = (driftState.rigPose = RigPose(
                    drift: CGSize(
                        width: motion.canopyHorizontalOffset,
                        height: motion.verticalBob
                    ),
                    bearDegrees: driftState.carriedSwingDegrees ?? motion.payloadRotationDegrees
                ))

                ZStack(alignment: .topLeading) {
                    VStack(spacing: -RiggingLines.bearOverlap) {
                        // The lines' own crop starts a couple of the artwork's units above the hem,
                        // so they are pulled up by exactly that much: the tops then land on the
                        // canopy's hem, which is the bottom edge of the card.
                        VStack(spacing: -RiggingLines.hemOverlap(forWidth: RigLayout.cardWidth)) {
                            ParachuteEventCard(
                                event: viewModel.nextEvent,
                                countdownText: viewModel.countdownText,
                                authorizationState: viewModel.authorizationState,
                                mood: viewModel.mood,
                                appearance: settings.appearance,
                                onTap: { CalendarLauncher.open(viewModel.nextEvent) }
                            )
                            .padding(.top, RigLayout.cardTopInset)

                            RiggingLinesView()
                                .frame(width: RigLayout.cardWidth, height: RigLayout.linesHeight)
                        }
                        .rotationEffect(.degrees(motion.canopyRotationDegrees), anchor: .bottom)

                    BearCharacterView(
                        mood: viewModel.mood,
                        appearance: settings.appearance,
                        onBellyTap: {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                                viewModel.toggleExpanded()
                            }
                        }
                    )
                        .frame(width: RigLayout.bearSize.width, height: RigLayout.bearSize.height)
                        .rotationEffect(
                            .degrees(driftState.carriedSwingDegrees ?? motion.payloadRotationDegrees),
                            anchor: .top
                        )
                        .contentShape(Rectangle())
                    }
                    .frame(width: RigLayout.windowSize.width, alignment: .top)
                    .offset(x: motion.canopyHorizontalOffset, y: motion.verticalBob)
                    // Deliberately **no** `contentShape` here. The window is 500 wide so the rig
                    // can overhang a screen edge — see `centerTravelBounds` — but the rig itself is
                    // only 244, and a shape on this frame handed the empty padding either side of
                    // it to the drag gesture. That padding is over someone's desktop: it swallowed
                    // clicks meant for whatever was behind it. Hit testing is left to the parts
                    // that are actually drawn — the canopy answers for its own outline, the bear
                    // for its box, the lines for their strokes — so everywhere else falls through.
                    //
                    // Grab anywhere on the rig and put it down anywhere on screen; the descent
                    // picks up again from wherever it lands. `simultaneousGesture` with a minimum
                    // distance leaves the belly tap working.
                    //
                    // The gesture's own `translation` is unusable here: it is measured in the
                    // view's space, and the view moves with the window, so following it cancels
                    // itself out. `NSEvent.mouseLocation` is absolute and does not.
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 3)
                            .onChanged { _ in driftState.carry(toScreenPoint: NSEvent.mouseLocation) }
                            .onEnded { _ in driftState.drop() }
                    )

                    if viewModel.isExpanded {
                        // Placed by the tail's **tip**, not by the bubble's corner: the corner is
                        // wherever the artwork's box happens to put it, and the thing that has to
                        // land on the bear is the point the tail aims at.
                        BearGreetingBubble(userName: CurrentUserGreeting.displayName)
                            .offset(
                                x: Self.bubbleTarget.x - BearGreetingBubble.tailTip.x
                                    + motion.canopyHorizontalOffset,
                                y: Self.bubbleTarget.y - BearGreetingBubble.tailTip.y
                                    + motion.verticalBob
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .bottomLeading)))
                    }
                }
                .frame(width: RigLayout.windowSize.width, height: RigLayout.windowSize.height, alignment: .topLeading)
            }
        }
        .frame(width: RigLayout.windowSize.width, height: RigLayout.windowSize.height, alignment: .topLeading)
    }

    /// Where the greeting's tail points: the bear's own upper body, a little left of its middle.
    /// The bubble hangs above and to the left of this, because that is the way the tail is drawn.
    static let bubbleTarget = CGPoint(
        x: RigLayout.bearRect.midX - 24,
        y: RigLayout.bearRect.minY + 34
    )
}

private struct RiggingLinesView: View {
    var body: some View {
        RiggingLines()
            .stroke(
                .secondary.opacity(0.46),
                style: StrokeStyle(lineWidth: RiggingLines.lineWidth, lineCap: .round)
            )
    }
}

/// One suspension line from every point where two scallops of the canopy meet, all gathering into
/// the same knot above the bear's head.
///
/// Drawn rather than cropped out of `parachute.svg`, because the artwork only strokes the
/// outermost pair — the five inner points had nothing hanging from them. Every coordinate below is
/// the artwork's own, so it can be checked against the file directly, and `path(in:)` converts them
/// through the same crop the canopy is drawn from. That is what keeps the tops landing exactly on
/// the canopy's points however the view is sized.
struct RiggingLines: Shape {
    /// The region of `parachute.svg` this view stands in for.
    static let sourceRect = CGRect(x: 252, y: 582, width: 478, height: 253)
    /// The hem, from `parachute.svg`'s scalloped path: seven points, evenly spaced 75.3 apart.
    static let hemY: Double = 584
    static let firstHemX: Double = 264.34
    static let lastHemX: Double = 716.15
    static let lineCount = 7
    /// Where the artwork's own two lines meet, which is the top of the bear's head.
    static let knot = CGPoint(x: 490.24, y: 731.94)
    /// How far the bear's frame is pulled up over the bottom of this view, as the `VStack` spacing
    /// in `BearOverlayView`. The riser's length is measured against it, so the two are stated in one
    /// place.
    static let bearOverlap: CGFloat = 32
    /// The riser carrying on below the knot onto the bear. It ends just inside the crown of the
    /// bear's head — a few units into the overlap — rather than following the artwork's own `<line>`
    /// down to 834.63. The bear is the only thing hiding this end, and the bear swings independently
    /// of the canopy: anything reaching further down is covered only while the two happen to be
    /// aligned, and works loose as a stray thread the moment the rig is shaken about.
    static let riserEndY: Double = 785
    /// How far each line bows up off its straight chord, as a fraction of how far that line travels
    /// sideways.
    ///
    /// Measuring against the sideways travel rather than the length is what keeps the fan
    /// symmetric: the middle line hangs straight down, has nothing to sag sideways, and stays dead
    /// straight, while the outermost pair — which reach furthest across — bow the most. The
    /// artwork's own two lines bow by about 3% of their chord; a little more than that reads as
    /// rope without looking slack.
    static let bow: Double = 0.11
    /// The artwork's 1.35 stroke, at the scale this view draws it.
    static let lineWidth: CGFloat = 1.35 * 244 / sourceRect.width

    /// How far this view has to be pulled up under the canopy for the tops of the lines to land on
    /// the hem: the distance between the top of this crop and the hem, at the drawn scale.
    static func hemOverlap(forWidth width: CGFloat) -> CGFloat {
        (hemY - sourceRect.minY) * width / sourceRect.width
    }

    func path(in rect: CGRect) -> Path {
        let scale = rect.width / Self.sourceRect.width
        let place = { (point: CGPoint) in
            CGPoint(
                x: rect.minX + (point.x - Self.sourceRect.minX) * scale,
                y: rect.minY + (point.y - Self.sourceRect.minY) * scale
            )
        }
        let span = Self.lastHemX - Self.firstHemX
        var path = Path()

        for index in 0..<Self.lineCount {
            let across = Double(index) / Double(Self.lineCount - 1)
            let top = CGPoint(x: Self.firstHemX + span * across, y: Self.hemY)
            // Lifting the control point pulls the curve up off the chord, so each line leaves the
            // hem shallow and steepens as it comes into the knot — the way a loaded line hangs.
            let control = CGPoint(
                x: (top.x + Self.knot.x) / 2,
                y: (top.y + Self.knot.y) / 2 - Self.bow * abs(top.x - Self.knot.x)
            )

            path.move(to: place(top))
            path.addQuadCurve(to: place(Self.knot), control: place(control))
        }

        path.move(to: place(Self.knot))
        path.addLine(to: place(CGPoint(x: Self.knot.x, y: Self.riserEndY)))

        return path
    }
}
