import AppKit
import SwiftUI

struct BearGreetingBubble: View {
    static let canvasSize = CGSize(width: 196, height: 50)
    static let bubbleOffset = CGPoint(x: 0, y: 0)
    static let tailOffset = CGPoint(x: 151, y: 21)

    let userName: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            SpeechBubbleTail()
                .fill(.regularMaterial)
                .frame(width: 15, height: 12)
                .offset(x: Self.tailOffset.x, y: Self.tailOffset.y)
                .overlay {
                    SpeechBubbleTail()
                        .stroke(.white.opacity(0.34), lineWidth: 1)
                        .frame(width: 15, height: 12)
                        .offset(x: Self.tailOffset.x, y: Self.tailOffset.y)
                }

            Text("Hello \"\(userName)\"")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(minWidth: 148, minHeight: 34)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .strokeBorder(.white.opacity(0.38), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 5)
                .offset(x: Self.bubbleOffset.x, y: Self.bubbleOffset.y)
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height, alignment: .topLeading)
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

private struct SpeechBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY),
                control: CGPoint(x: rect.maxX * 0.55, y: rect.midY)
            )
            path.closeSubpath()
        }
    }
}
