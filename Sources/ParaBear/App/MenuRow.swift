import AppKit

/// The shape every setting row in the menu shares: one caption on the left, one control on the
/// right, one set of insets.
///
/// It was three copies of the same eleven lines inside `MenuBarController`, and three copies are
/// three places for the insets to drift apart. Stated once here rather than as a private method
/// there for a second reason: a row is the only part of the menu that can be looked at without a
/// status item, so `MenuBarSnapshot` can render the real thing instead of a rebuilt likeness.
///
/// Only the two numbers that genuinely differ are parameters. A segmented control draws its own
/// edge padding, so it sits a couple of points further out than a control that does not.
enum MenuRow {
    /// Menu rows are laid out against this width; `NSMenu` widens the whole menu to its widest item.
    static let width: CGFloat = 210

    static func make(
        title: String,
        control: NSView,
        height: CGFloat,
        rightInset: CGFloat
    ) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor

        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 12
        row.edgeInsets = NSEdgeInsets(top: 4, left: 12, bottom: 8, right: rightInset)
        row.frame = NSRect(x: 0, y: 0, width: width, height: height)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.setContentHuggingPriority(.required, for: .horizontal)
        return row
    }

    /// The rows built around a segmented control, which is most of them.
    static func make(title: String, control: NSSegmentedControl) -> NSStackView {
        control.segmentStyle = .rounded
        control.controlSize = .small

        return make(title: title, control: control, height: 34, rightInset: 10)
    }
}
