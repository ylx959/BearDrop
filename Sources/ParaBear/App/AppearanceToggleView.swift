import AppKit

/// The light/dark toggle in the menu: a capsule track, a round knob that slides from one end to the
/// other, and a single icon on the side the knob has left.
///
/// The icon is the scheme you are **not** in — sun while dark, moon while light — so the control
/// reads as "tap here to go there" rather than as a label for the current state. The knob would
/// cover it otherwise, which is the whole reason a slider only ever needs one.
///
/// The track previews what it selects: near-black on `.dark`, near-white on `.light`. That is also
/// why nothing here uses a semantic `NSColor`. This control stands for the *rig's* scheme, which is
/// deliberately independent of the system's — see `RigAppearance` — and a track painted in
/// `.controlBackgroundColor` would flip with macOS while the thing it selects stayed put.
///
/// Written in AppKit rather than SwiftUI on purpose: it lives inside an `NSMenu`, which runs its
/// own event-tracking loop, and a plain `NSView` is what reliably receives a click there.
final class AppearanceToggleView: NSView {
    var onChange: ((RigAppearance) -> Void)?

    /// Named `scheme`, not `appearance`: `NSView` already has an `appearance`, and it is the
    /// `NSAppearance` this control exists to *not* be tied to.
    private(set) var scheme: RigAppearance

    /// Menu-row scale, not window scale: it sits next to an 11pt label, so the track is only a
    /// little taller than the text beside it. The three sizes below hold their ratios — track
    /// height, a knob inset from it, an icon a shade smaller than the knob — so nudging the height
    /// is the only change that makes sense to make here.
    private static let size = NSSize(width: 42, height: 23)
    /// How far the knob sits inside the track.
    private static let inset: CGFloat = 2.5
    private static let iconSize: CGFloat = 11
    private static let slide: TimeInterval = 0.24

    private let track = CALayer()
    private let knob = CALayer()
    private let icon = CALayer()

    private static let icons: [RigAppearance: NSImage] = {
        let configuration = NSImage.SymbolConfiguration(
            pointSize: iconSize,
            weight: .medium
        )

        return Dictionary(
            uniqueKeysWithValues: RigAppearance.allCases.compactMap { scheme in
                NSImage(
                    systemSymbolName: scheme.symbolName,
                    accessibilityDescription: scheme.title
                )?
                .withSymbolConfiguration(configuration)
                .map { (scheme, $0) }
            }
        )
    }()

    init(scheme: RigAppearance) {
        self.scheme = scheme
        super.init(frame: NSRect(origin: .zero, size: Self.size))

        wantsLayer = true
        layer?.addSublayer(track)
        track.addSublayer(knob)
        track.addSublayer(icon)

        track.frame = bounds
        track.cornerRadius = bounds.height / 2
        knob.cornerRadius = knobDiameter / 2
        knob.bounds = CGRect(x: 0, y: 0, width: knobDiameter, height: knobDiameter)
        knob.shadowOffset = CGSize(width: 0, height: -1)
        knob.shadowRadius = 1.5
        knob.shadowOpacity = 0.22
        icon.bounds = CGRect(x: 0, y: 0, width: Self.iconSize, height: Self.iconSize)
        icon.contentsGravity = .resizeAspect

        show(scheme, animated: false)

        setAccessibilityRole(.button)
        setAccessibilityLabel("Appearance")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize { Self.size }

    override func mouseDown(with event: NSEvent) {
        let next = scheme.toggled
        scheme = next
        show(next, animated: true)
        onChange?(next)
    }

    /// Kept in step when something other than a click changes the setting.
    func setScheme(_ scheme: RigAppearance) {
        guard scheme != self.scheme else { return }
        self.scheme = scheme
        show(scheme, animated: true)
    }

    private var knobDiameter: CGFloat { bounds.height - Self.inset * 2 }

    /// The knob is on the right while dark and on the left while light; the icon takes whichever
    /// end is free.
    private func centres(for scheme: RigAppearance) -> (knob: CGFloat, icon: CGFloat) {
        let near = Self.inset + knobDiameter / 2
        let far = bounds.width - near

        switch scheme {
        case .dark: return (knob: far, icon: near)
        case .light: return (knob: near, icon: far)
        }
    }

    private func show(_ scheme: RigAppearance, animated: Bool) {
        let centre = centres(for: scheme)
        let middle = bounds.height / 2
        let colours = Self.colours(for: scheme)

        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        CATransaction.setAnimationDuration(Self.slide)
        CATransaction.setAnimationTimingFunction(
            CAMediaTimingFunction(name: .easeInEaseOut)
        )

        if animated {
            // A layer inside an `NSView`'s backing layer has its implicit animations switched off,
            // so the slide is asked for by name.
            knob.add(slideAnimation(from: knob.position.x, to: centre.knob), forKey: "slide")
        }

        knob.position = CGPoint(x: centre.knob, y: middle)
        icon.position = CGPoint(x: centre.icon, y: middle)
        track.backgroundColor = colours.track
        knob.backgroundColor = colours.knob
        knob.shadowColor = colours.knobShadow
        icon.contents = Self.icons[scheme.toggled]?.tinted(colours.icon)

        CATransaction.commit()
    }

    private func slideAnimation(from: CGFloat, to: CGFloat) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "position.x")
        animation.fromValue = from
        animation.toValue = to
        animation.duration = Self.slide
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        return animation
    }

    private static func colours(
        for scheme: RigAppearance
    ) -> (track: CGColor, knob: CGColor, knobShadow: CGColor, icon: NSColor) {
        switch scheme {
        case .dark:
            (
                track: NSColor(calibratedWhite: 0.11, alpha: 1).cgColor,
                knob: NSColor.white.cgColor,
                knobShadow: NSColor.black.cgColor,
                icon: NSColor(calibratedWhite: 0.78, alpha: 1)
            )
        case .light:
            (
                track: NSColor(calibratedWhite: 0.91, alpha: 1).cgColor,
                knob: NSColor.white.cgColor,
                knobShadow: NSColor(calibratedWhite: 0.35, alpha: 1).cgColor,
                icon: NSColor(calibratedWhite: 0.34, alpha: 1)
            )
        }
    }
}

private extension NSImage {
    /// SF Symbols arrive as templates, and a template drawn straight into a `CALayer`'s `contents`
    /// has no colour to draw in — it comes out black on both schemes.
    func tinted(_ colour: NSColor) -> NSImage {
        let tinted = NSImage(size: size, flipped: false) { rect in
            colour.set()
            self.draw(in: rect)
            rect.fill(using: .sourceAtop)
            return true
        }
        tinted.isTemplate = false
        return tinted
    }
}
