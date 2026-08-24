import AppKit
import SwiftUI

@MainActor
struct SVGAssetView: View {
    let resourceName: String
    let subdirectory: String?
    let sourceViewBox: CGSize
    let visibleRect: CGRect
    let renderingMode: Image.TemplateRenderingMode?
    /// Colours to rewrite on the way in, as `from hex: to hex`. Empty draws the file as authored.
    let recolouring: [String: String]

    init(
        resourceName: String,
        subdirectory: String? = nil,
        sourceViewBox: CGSize = CGSize(width: 1005, height: 1215.8),
        visibleRect: CGRect,
        renderingMode: Image.TemplateRenderingMode? = nil,
        recolouring: [String: String] = [:]
    ) {
        self.resourceName = resourceName
        self.subdirectory = subdirectory
        self.sourceViewBox = sourceViewBox
        self.visibleRect = visibleRect
        self.renderingMode = renderingMode
        self.recolouring = recolouring
    }

    var body: some View {
        GeometryReader { proxy in
            if let image = Self.image(
                resourceName: resourceName,
                subdirectory: subdirectory,
                recolouring: recolouring
            ) {
                let scale = max(
                    proxy.size.width / visibleRect.width,
                    proxy.size.height / visibleRect.height
                )

                Image(nsImage: image)
                    .renderingMode(renderingMode)
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: sourceViewBox.width * scale,
                        height: sourceViewBox.height * scale
                    )
                    .offset(
                        x: -visibleRect.minX * scale,
                        y: -visibleRect.minY * scale
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            } else {
                Color.clear
            }
        }
        .clipped()
    }

    static func assetURL(resourceName: String, subdirectory: String?) -> URL? {
        let bundle = Bundle.packagedResources
        let nestedURL = bundle.url(
            forResource: resourceName,
            withExtension: "svg",
            subdirectory: subdirectory
        )
        return nestedURL ?? bundle.url(forResource: resourceName, withExtension: "svg")
    }

    /// Every `#rrggbb` in `svg` looked up in `recolouring`, all in **one pass**.
    ///
    /// One pass is the whole point. The schemes this serves swap two colours, and applying such a
    /// map one rule after another cannot express a swap: the first rule paints every black shape
    /// white, and the second then paints all of them — the ones that were already white included —
    /// black. Rewriting each match exactly once from the original text is what keeps the two
    /// colours distinct.
    ///
    /// Matching is case-insensitive on the hex digits but the replacement is written verbatim, so
    /// a file mixing `#FFF000` and `#fff000` still recolours as one colour.
    static func recoloured(_ svg: String, _ recolouring: [String: String]) -> String {
        guard !recolouring.isEmpty else { return svg }

        let table = Dictionary(
            uniqueKeysWithValues: recolouring.map { ($0.key.uppercased(), $0.value) }
        )

        var result = ""
        var index = svg.startIndex

        while let hash = svg[index...].firstIndex(of: "#") {
            let hexEnd = svg.index(hash, offsetBy: 7, limitedBy: svg.endIndex) ?? svg.endIndex
            let token = String(svg[hash..<hexEnd])

            result += svg[index..<hash]

            if token.count == 7, let replacement = table[token.uppercased()] {
                result += replacement
            } else {
                result += token
            }

            index = hexEnd
        }

        result += svg[index...]
        return result
    }

    /// Decoding an SVG and rasterising it is far too slow to do on every frame, and the rig redraws
    /// at 60fps under a `TimelineView`. Keyed by the recolouring as well as the file, so both
    /// schemes stay resident once seen and switching between them costs nothing.
    private static var cache: [String: NSImage] = [:]

    private static func image(
        resourceName: String,
        subdirectory: String?,
        recolouring: [String: String]
    ) -> NSImage? {
        let key = [
            subdirectory ?? "",
            resourceName,
            recolouring.sorted { $0.key < $1.key }.map { "\($0.key)>\($0.value)" }.joined(separator: ",")
        ].joined(separator: "/")

        if let cached = cache[key] {
            return cached
        }

        guard let url = assetURL(resourceName: resourceName, subdirectory: subdirectory) else {
            return nil
        }

        let image: NSImage?

        if recolouring.isEmpty {
            image = NSImage(contentsOf: url)
        } else if let svg = try? String(contentsOf: url, encoding: .utf8) {
            image = NSImage(data: Data(recoloured(svg, recolouring).utf8))
        } else {
            image = nil
        }

        if let image {
            cache[key] = image
        }

        return image
    }
}
