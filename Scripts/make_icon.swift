import AppKit

// White squircle, pawprint in the top-left corner.
//
// The paw is `pawprint.fill` — the same symbol the menu bar icon badges onto its calendar, so the
// two read as the same app. Its colour is the bear's own #14161C rather than #000: a pure black
// mark on white reads as a hole punched in the icon, which is the same reason the artwork avoids it.

let fur = NSColor(srgbRed: 0x14 / 255.0, green: 0x16 / 255.0, blue: 0x1C / 255.0, alpha: 1)

/// macOS's icon grid: the body does not fill the canvas. A full-bleed square sits noticeably larger
/// than every other icon in the Dock, because the system sizes them all against this inset.
let bodyShare: CGFloat = 824.0 / 1024.0
let cornerShare: CGFloat = 185.4 / 824.0
/// How much of the body the paw takes, and how far it is held off the corner.
let pawShare: CGFloat = 0.34
let insetShare: CGFloat = 0.115

func fit(_ size: NSSize, in box: CGRect) -> CGRect {
    let scale = min(box.width / size.width, box.height / size.height)
    let fitted = NSSize(width: size.width * scale, height: size.height * scale)
    return CGRect(
        x: box.midX - fitted.width / 2,
        y: box.midY - fitted.height / 2,
        width: fitted.width,
        height: fitted.height
    )
}

func icon(side: CGFloat) -> NSImage {
    let canvas = NSSize(width: side, height: side)
    let body = CGRect(x: 0, y: 0, width: side, height: side)
        .insetBy(dx: side * (1 - bodyShare) / 2, dy: side * (1 - bodyShare) / 2)

    return NSImage(size: canvas, flipped: false) { _ in
        guard let context = NSGraphicsContext.current else { return false }
        context.imageInterpolation = .high

        // A soft shadow so the white body still has an edge on a white Finder background.
        context.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
        shadow.shadowBlurRadius = side * 0.022
        shadow.shadowOffset = NSSize(width: 0, height: -side * 0.012)
        shadow.set()

        let shape = NSBezierPath(
            roundedRect: body,
            xRadius: body.width * cornerShare,
            yRadius: body.width * cornerShare
        )
        NSColor.white.setFill()
        shape.fill()
        context.restoreGraphicsState()

        // A hairline edge, for the same reason: pure white on pure white is invisible otherwise.
        NSColor.black.withAlphaComponent(0.08).setStroke()
        shape.lineWidth = max(1, side * 0.0025)
        shape.stroke()

        guard
            let paw = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(
                    NSImage.SymbolConfiguration(pointSize: side, weight: .regular)
                        .applying(NSImage.SymbolConfiguration(hierarchicalColor: fur))
                )
        else { return false }

        let box = CGRect(
            x: body.minX + body.width * insetShare,
            y: body.maxY - body.height * insetShare - body.height * pawShare,
            width: body.width * pawShare,
            height: body.height * pawShare
        )
        paw.draw(in: fit(paw.size, in: box), from: .zero, operation: .sourceOver, fraction: 1)
        return true
    }
}

func write(_ image: NSImage, to url: URL, pixels: Int) throws {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

// Each size is drawn at its own scale rather than downsampled from 1024 — the paw's toes are small
// enough at 16pt that resampling turns them to mush.
let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]

for (name, pixels) in sizes {
    try write(icon(side: CGFloat(pixels)), to: out.appendingPathComponent("\(name).png"), pixels: pixels)
}
print("wrote \(sizes.count) sizes to \(out.path)")
