import AppKit

/// The switch the menu uses: a capsule track, a round knob that slides from one end to the other,
/// and an optional icon on whichever end the knob has left.
///
/// Both toggles in the menu are this control, so the geometry is stated once — the two of them sit
/// two rows apart and a switch that is a couple of points taller than the one above it reads as a
/// mistake before it reads as anything else. The three sizes hold their ratios (track height, a knob
/// inset from it, an icon a shade smaller than the knob), so nudging the height is the only change
/// that makes sense to make here.
///
/// Written in AppKit rather than SwiftUI on purpose: it lives inside an `NSMenu`, which runs its own
/// event-tracking loop, and a plain `NSView` is what reliably receives a click there. It is drawn
/// rather than being an `NSSwitch` because `NSSwitch` sizes itself — `.small` lands it visibly
/// shorter than the appearance toggle beside it, and nothing about its size is ours to set.
///
/// Subclasses say what each side *means* and what it looks like; everything about how the knob gets
/// there lives here.
class MenuToggleView: NSView {
    /// What one side of the switch looks like. The colours are taken fresh on every change so a
    /// subclass may return semantic `NSColor`s — see `viewDidChangeEffectiveAppearance`.
    struct Look {
        let track: NSColor
        let knob: NSColor
        let knobShadow: NSColor
        /// Drawn on the end the knob is *not* at, or nothing at all.
        let icon: NSImage?
    }

    /// Menu-row scale, not window scale: it sits next to an 11pt label, so the track is only a
    /// little taller than the text beside it.
    static let size = NSSize(width: 42, height: 23)
    /// How far the knob sits inside the track.
    static let inset: CGFloat = 2.5
    static let iconSize: CGFloat = 11
    private static let slide: TimeInterval = 0.24

    /// Whether the knob is at the trailing end. What that *means* is the subclass's business.
    private(set) var isOn: Bool

    private let track = CALayer()
    private let knob = CALayer()
    private let icon = CALayer()

    init(isOn: Bool) {
        self.isOn = isOn
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

        setAccessibilityRole(.button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize { Self.size }

    /// A switch that cannot be thrown says so by fading, and stops taking clicks. `LoginToggleView`
    /// is the only one that is ever off the table — see `LoginItem.isAvailable`.
    var isEnabled: Bool = true {
        didSet { alphaValue = isEnabled ? 1 : 0.4 }
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }

        show(!isOn, animated: true)
        didToggle(to: isOn)
    }

    /// Kept in step when something other than a click changes what the switch stands for.
    func setOn(_ isOn: Bool, animated: Bool = true) {
        guard isOn != self.isOn else { return }
        show(isOn, animated: animated)
    }

    // MARK: - For subclasses

    /// What the control looks like with the knob at each end.
    func look(for isOn: Bool) -> Look {
        fatalError("MenuToggleView subclasses must say what each side looks like")
    }

    /// The click landed and the knob has started moving.
    func didToggle(to isOn: Bool) {}

    /// Call once the subclass is ready to answer `look(for:)` — an initializer cannot, since it runs
    /// before the subclass's own stored properties exist.
    final func drawInitialState() {
        show(isOn, animated: false)
    }

    // MARK: - Drawing

    private var knobDiameter: CGFloat { bounds.height - Self.inset * 2 }

    private func centres(for isOn: Bool) -> (knob: CGFloat, icon: CGFloat) {
        let near = Self.inset + knobDiameter / 2
        let far = bounds.width - near

        return isOn ? (knob: far, icon: near) : (knob: near, icon: far)
    }

    private func show(_ isOn: Bool, animated: Bool) {
        self.isOn = isOn

        let centre = centres(for: isOn)
        let middle = bounds.height / 2
        // Semantic colours resolve against whatever appearance is current when they are asked for
        // a `cgColor`, and a `CALayer` keeps no colour it can re-resolve later. Inside the menu the
        // current appearance is not necessarily this view's.
        let look = effectiveAppearance.withCurrentDrawing { self.look(for: isOn) }

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
        track.backgroundColor = look.track.cgColor
        knob.backgroundColor = look.knob.cgColor
        knob.shadowColor = look.knobShadow.cgColor
        icon.contents = look.icon

        CATransaction.commit()
    }

    /// macOS switching between light and dark, which the menu follows even though the rig does not.
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        show(isOn, animated: false)
    }

    private func slideAnimation(from: CGFloat, to: CGFloat) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "position.x")
        animation.fromValue = from
        animation.toValue = to
        animation.duration = Self.slide
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        return animation
    }
}

extension NSAppearance {
    /// `performAsCurrentDrawingAppearance` with a value carried back out of it.
    func withCurrentDrawing<T>(_ body: () -> T) -> T {
        var value: T?
        performAsCurrentDrawingAppearance { value = body() }
        return value!
    }
}

extension NSImage {
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
