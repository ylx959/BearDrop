import AppKit

/// The light/dark toggle in the menu.
///
/// The icon is the scheme you are **not** in — sun while dark, moon while light — so the control
/// reads as "tap here to go there" rather than as a label for the current state. The knob would
/// cover it otherwise, which is the whole reason a slider only ever needs one.
///
/// The track previews what it selects: near-black on `.dark`, near-white on `.light`. That is also
/// why nothing here uses a semantic `NSColor`, and the one place this control parts company with
/// `LoginToggleView` next to it. This one stands for the *rig's* scheme, which is deliberately
/// independent of the system's — see `RigAppearance` — and a track painted in
/// `.controlBackgroundColor` would flip with macOS while the thing it selects stayed put.
///
/// Everything about the capsule, the knob and its slide is `MenuToggleView`: the two switches in
/// the menu are the same control, so they are the same size and the same shape by construction
/// rather than by two sets of numbers agreeing.
final class AppearanceToggleView: MenuToggleView {
    var onChange: ((RigAppearance) -> Void)?

    /// Named `scheme`, not `appearance`: `NSView` already has an `appearance`, and it is the
    /// `NSAppearance` this control exists to *not* be tied to.
    ///
    /// Derived rather than stored — the knob's end and the scheme are one fact, and storing it
    /// twice is storing it once too often.
    var scheme: RigAppearance { isOn ? .dark : .light }

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
        super.init(isOn: scheme == .dark)
        setAccessibilityLabel("Appearance")
        drawInitialState()
    }

    /// Kept in step when something other than a click changes the setting.
    func setScheme(_ scheme: RigAppearance) {
        setOn(scheme == .dark)
    }

    override func didToggle(to isOn: Bool) {
        onChange?(scheme)
    }

    override func look(for isOn: Bool) -> Look {
        let scheme: RigAppearance = isOn ? .dark : .light

        switch scheme {
        case .dark:
            return Look(
                track: NSColor(calibratedWhite: 0.11, alpha: 1),
                knob: .white,
                knobShadow: .black,
                icon: Self.icons[scheme.toggled]?.tinted(NSColor(calibratedWhite: 0.78, alpha: 1))
            )
        case .light:
            return Look(
                track: NSColor(calibratedWhite: 0.91, alpha: 1),
                knob: .white,
                knobShadow: NSColor(calibratedWhite: 0.35, alpha: 1),
                icon: Self.icons[scheme.toggled]?.tinted(NSColor(calibratedWhite: 0.34, alpha: 1))
            )
        }
    }
}
