import Foundation
import Testing
@testable import ParaBear

@MainActor
struct RigAppearanceTests {
    @Test func theTwoSchemesUseEachOthersColours() {
        #expect(RigAppearance.dark.fur == RigAppearance.light.detail)
        #expect(RigAppearance.dark.detail == RigAppearance.light.fur)
        #expect(RigAppearance.dark.toggled == .light)
        #expect(RigAppearance.light.toggled == .dark)
    }

    /// The bear's two colours swap between schemes, and the substitution has to happen in one pass
    /// for that to survive. Applied one rule after another it would paint the whole bear a single
    /// colour: the first rule turns every black shape white, and the second turns all of them —
    /// including the ones that were already white — black.
    @Test func swappingTwoColoursKeepsThemDistinct() {
        let svg = """
        <style>.cls-1{fill:#14161C;}.cls-2{fill:#FFFFFF;}\
        .cls-3{stroke:#FFFFFF;stroke-opacity:0.46;}</style>
        """

        let light = SVGAssetView.recoloured(svg, RigAppearance.light.bearRecolouring)

        #expect(light.contains(".cls-1{fill:#FFFFFF;}"))
        #expect(light.contains(".cls-2{fill:#14161C;}"))
        #expect(light.contains("stroke:#14161C;"))
    }

    @Test func theDarkSchemeLeavesTheArtworkAsAuthored() {
        let svg = "<style>.cls-1{fill:#14161C;}.cls-2{fill:#FFFFFF;}</style>"
        #expect(SVGAssetView.recoloured(svg, RigAppearance.dark.bearRecolouring) == svg)
    }

    /// The bear's own two colours are the only ones rewritten; anything else in the file — and any
    /// `#` that is not a colour at all — comes through untouched.
    @Test func coloursOutsideTheTableSurvive() {
        let svg = ##"<style>.a{fill:#8b6c5c;}.b{fill:#14161C;}</style><a href="#layer2"/>"##
        let light = SVGAssetView.recoloured(svg, RigAppearance.light.bearRecolouring)

        #expect(light.contains("fill:#8b6c5c;"))
        #expect(light.contains("fill:#FFFFFF;"))
        #expect(light.contains(##"href="#layer2""##))
    }

    @Test func lowercaseHexIsMatchedToo() {
        let recoloured = SVGAssetView.recoloured(
            "fill:#14161c;",
            RigAppearance.light.bearRecolouring
        )
        #expect(recoloured == "fill:#FFFFFF;")
    }

    /// The files on disk are authored in the dark scheme, and `bearRecolouring` is written against
    /// that. If the artwork is ever re-exported in different colours this is what says so.
    @Test func theArtworkOnDiskIsInTheDarkScheme() throws {
        for name in ["bear", "bear_body", "bear_wave_arm"] {
            let url = try #require(
                SVGAssetView.assetURL(resourceName: name, subdirectory: "Bear")
            )
            let svg = try String(contentsOf: url, encoding: .utf8)

            #expect(svg.contains(RigAppearance.dark.fur), "\(name) is missing the fur colour")
        }
    }
}
