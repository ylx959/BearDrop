import AppKit
import SwiftUI

struct BearGreetingBubble: View {
    /// Sized so the capsule is a comfortable height for 13pt type once the artwork's proportion is
    /// honoured — the shape is very wide (the body is 4.18:1), so the width decides the height and
    /// not the other way round.
    static let width: CGFloat = 176

    static var height: CGFloat { SpeechBubble.height(forWidth: width) }
    static var bodyHeight: CGFloat { SpeechBubble.bodyHeight(forWidth: width) }
    /// Where the tail points. `BearOverlayView` places the bubble by this, not by its corner.
    static var tailTip: CGPoint { SpeechBubble.tailTip(forWidth: width) }

    let userName: String

    var body: some View {
        Text("Hello \"\(userName)\"")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 18)
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
            .accessibilityLabel("Hello \(userName)")
    }
}

enum CurrentUserGreeting {
    static var displayName: String {
        let fullName = NSFullUserName()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !fullName.isEmpty {
            return fullName
        }

        let shortName = NSUserName()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return shortName.isEmpty ? "friend" : shortName
    }
}
