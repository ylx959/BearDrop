import Testing
@testable import ParaBear

struct SVGAssetViewTests {
    @MainActor
    @Test func findsFlattenedBearAssetWhenSubdirectoryIsProvided() {
        let url = SVGAssetView.assetURL(resourceName: "bear", subdirectory: "Bear")

        #expect(url?.lastPathComponent == "bear.svg")
    }

    @MainActor
    @Test func findsParachuteAssetAtBundleRoot() {
        let url = SVGAssetView.assetURL(resourceName: "parachute", subdirectory: nil)

        #expect(url?.lastPathComponent == "parachute.svg")
    }
}
