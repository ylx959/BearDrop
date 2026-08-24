import AppKit
import SwiftUI

struct BearGreetingBubble: View {
    /// Wide enough for the remarks, and no wider than the gap allows.
    ///
    /// Both ends of that are real. The longest line — "I'm watching you procrastinate." — measures
    /// 194pt at 13pt, which no single-line bubble here can hold: the bubble has to clear the bear
    /// and stay on the window, which caps it around 189. So it wraps to two lines instead of being
    /// shrunk to fit, and the artwork turns out to have room — the capsule's own proportion gives a
    /// 42pt body at this width, which is two lines of 13pt with air to spare. Shrinking was the
    /// alternative and it lands the longest remarks at about 10pt, noticeably smaller than the
    /// short ones sitting in the same bubble a tap earlier.
    static let width: CGFloat = 176

    static var height: CGFloat { SpeechBubble.height(forWidth: width) }
    static var bodyHeight: CGFloat { SpeechBubble.bodyHeight(forWidth: width) }

    let remark: String

    var body: some View {
        Text(remark)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 14)
            // Centred in the **capsule**, not in the canvas: the canvas includes the tail, and
            // centring on that would push the text down off the middle of the bubble by half the
            // tail's height.
            .frame(width: Self.width, height: Self.bodyHeight)
            .frame(width: Self.width, height: Self.height, alignment: .top)
            .background {
                SpeechBubble()
                    .fill(.regularMaterial)
                    .overlay {
                        SpeechBubble().stroke(.white.opacity(0.38), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 5)
            }
            .accessibilityLabel(remark)
    }
}
