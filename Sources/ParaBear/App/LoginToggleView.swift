import AppKit

/// The "Open at login" switch in the menu — the same control as `AppearanceToggleView`, saying an
/// ordinary on and off.
///
/// **Semantic colours, unlike the toggle above it.** That one previews the rig's scheme, which has
/// nothing to do with macOS; this one is a plain switch sitting in a menu, and a menu follows the
/// system. So it is drawn in the system's own accent and in greys that resolve against whatever the
/// menu is — which is the whole reason `MenuToggleView` takes its colours fresh on every change
/// rather than once at build time.
///
/// **No icon on the free end.** The appearance toggle carries one because its two ends are two
/// schemes and neither is "off" — the sun says where tapping takes you. On and off need no such
/// help: the filled track already says which one is showing, and a glyph there would be a second
/// way of saying it, free to disagree.
final class LoginToggleView: MenuToggleView {
    var onChange: ((Bool) -> Void)?

    override init(isOn: Bool) {
        super.init(isOn: isOn)
        setAccessibilityLabel("Open at login")
        drawInitialState()
    }

    override func didToggle(to isOn: Bool) {
        onChange?(isOn)
    }

    override func look(for isOn: Bool) -> Look {
        Look(
            // The accent colour is what every other switch on the Mac fills with, including the one
            // in System Settings' own Login Items list — this row is about the same registration.
            track: isOn ? .controlAccentColor : .tertiaryLabelColor,
            knob: .white,
            knobShadow: .black,
            icon: nil
        )
    }
}
