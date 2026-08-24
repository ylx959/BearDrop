import SwiftUI

struct BearCharacterView: View {
    /// The bear's own box, stated once: its `visibleRect`, the aspect it holds itself to, and the
    /// box `RigLayout` gives it all come from here. Three separate statements of the same
    /// proportion had already drifted apart by most of a point.
    ///
    /// The artwork used to be one bear inside a much larger shared coordinate space, cropped to
    /// with a `visibleRect`; it is now exported as just the bear, so the crop is the whole file and
    /// `sourceRect` and the viewBox are the same rectangle.
    static let sourceRect = CGRect(x: 0, y: 0, width: 184, height: 353)

    static func height(forWidth width: CGFloat) -> CGFloat {
        width * sourceRect.height / sourceRect.width
    }

    let mood: BearMood
    var appearance: RigAppearance = .dark
    var onTap: () -> Void = {}
    @State private var bounceAmount = 0.0

    var body: some View {
        GeometryReader { proxy in
            let region = BearTapTarget.region(in: proxy.size)

            ZStack(alignment: .topLeading) {
                SVGAssetView(
                    resourceName: "bear",
                    subdirectory: "Bear",
                    sourceViewBox: Self.sourceRect.size,
                    visibleRect: Self.sourceRect,
                    recolouring: appearance.bearRecolouring
                )
                .scaleEffect(
                    x: 1 + bounceAmount * 0.08,
                    y: 1 - bounceAmount * 0.07,
                    anchor: .center
                )
                .offset(y: bounceAmount * 5.5)

                // The whole bear, not a patch of it. It was an ellipse over the belly, which meant
                // most of the animal — head, arms, legs — did nothing when you clicked it, and
                // nothing on screen said where the live part was. The window already answers for
                // the bear's whole box (`RigLayout.bearCovers`), so this is the region the pointer
                // was being captured for anyway.
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(width: region.width, height: region.height)
                    .position(x: region.midX, y: region.midY)
                    .highPriorityGesture(
                        TapGesture()
                            .onEnded {
                                triggerBounce()
                                onTap()
                            }
                    )
                    .accessibilityLabel("ParaBear")
            }
        }
        .aspectRatio(Self.sourceRect.width / Self.sourceRect.height, contentMode: .fit)
        .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 8)
        .accessibilityLabel("ParaBear")
    }

    private func triggerBounce() {
        withAnimation(.spring(response: 0.10, dampingFraction: 0.36)) {
            bounceAmount = 1
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.spring(response: 0.34, dampingFraction: 0.34)) {
                bounceAmount = 0
            }
        }
    }
}

/// Where a click on the bear counts.
///
/// The whole of it. This used to be an ellipse over the belly — about a fifth of the figure — and
/// the rest of the bear was inert with nothing to say so. A target you cannot see has to be the
/// obvious one, and on a drawing of an animal the obvious one is the animal.
///
/// It is the bear's **box**, not its silhouette, which means the empty corners either side of the
/// head count too. That is deliberate: the window already hands this exact box to the rig rather
/// than to the desktop (`RigLayout.bearCovers`), so those corners were being taken from whatever is
/// behind the bear regardless — the choice is only whether they do anything once taken.
enum BearTapTarget {
    static func region(in size: CGSize) -> CGRect {
        CGRect(origin: .zero, size: size)
    }
}
