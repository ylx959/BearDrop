import SwiftUI

struct BearCharacterView: View {
    let mood: BearMood
    var appearance: RigAppearance = .dark
    var onBellyTap: () -> Void = {}
    @State private var bellyBounceAmount = 0.0

    var body: some View {
        GeometryReader { proxy in
            let bellyRegion = BearBellyInteraction.region(in: proxy.size)

            ZStack(alignment: .topLeading) {
                SVGAssetView(
                    resourceName: "bear",
                    subdirectory: "Bear",
                    visibleRect: CGRect(x: 404, y: 642, width: 204, height: 371),
                    recolouring: appearance.bearRecolouring
                )
                .scaleEffect(
                    x: 1 + bellyBounceAmount * 0.08,
                    y: 1 - bellyBounceAmount * 0.07,
                    anchor: .center
                )
                .offset(y: bellyBounceAmount * 5.5)

                Ellipse()
                    .fill(Color.clear)
                    .contentShape(Ellipse())
                    .frame(width: bellyRegion.width, height: bellyRegion.height)
                    .position(x: bellyRegion.midX, y: bellyRegion.midY)
                    .highPriorityGesture(
                        TapGesture()
                            .onEnded {
                                triggerBellyBounce()
                                onBellyTap()
                            }
                    )
                    .accessibilityLabel("ParaBear belly")
            }
        }
        .aspectRatio(204 / 371, contentMode: .fit)
        .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 8)
        .accessibilityLabel("ParaBear")
    }

    private func triggerBellyBounce() {
        withAnimation(.spring(response: 0.10, dampingFraction: 0.36)) {
            bellyBounceAmount = 1
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.spring(response: 0.34, dampingFraction: 0.34)) {
                bellyBounceAmount = 0
            }
        }
    }
}

enum BearBellyInteraction {
    static func region(in size: CGSize) -> CGRect {
        CGRect(
            x: size.width * 0.23,
            y: size.height * 0.39,
            width: size.width * 0.54,
            height: size.height * 0.38
        )
    }
}
