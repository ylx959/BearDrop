import CoreGraphics
import Testing
@testable import ParaBear

struct BearBellyInteractionTests {
    @MainActor
    @Test func bellyTapRegionStaysAroundTorso() {
        let region = BearBellyInteraction.region(in: CGSize(width: 106, height: 192))

        #expect(region.midX > 45)
        #expect(region.midX < 61)
        #expect(region.minY > 70)
        #expect(region.maxY < 155)
        #expect(region.width > 50)
        #expect(region.height > 65)
    }
}
