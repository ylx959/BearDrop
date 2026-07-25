import SwiftUI

struct BearCharacterView: View {
    let mood: BearMood

    var body: some View {
        ZStack {
            ears
            head
            face
        }
        .accessibilityLabel("ParaBear")
    }

    private var ears: some View {
        HStack(spacing: 58) {
            Circle()
                .fill(Color(red: 0.72, green: 0.55, blue: 0.40))
                .frame(width: 34, height: 34)
            Circle()
                .fill(Color(red: 0.72, green: 0.55, blue: 0.40))
                .frame(width: 34, height: 34)
        }
        .offset(y: -32)
    }

    private var head: some View {
        RoundedRectangle(cornerRadius: 42, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.78, green: 0.62, blue: 0.47),
                        Color(red: 0.66, green: 0.49, blue: 0.36)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 104, height: 92)
            .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 9)
    }

    private var face: some View {
        VStack(spacing: 10) {
            eyes
            muzzle
        }
        .offset(y: 4)
    }

    private var eyes: some View {
        HStack(spacing: 28) {
            eye
            eye
        }
    }

    private var eye: some View {
        Group {
            switch mood {
            case .calm:
                Capsule()
                    .fill(.black.opacity(0.72))
                    .frame(width: 9, height: 13)
            case .alert:
                Circle()
                    .fill(.black.opacity(0.72))
                    .frame(width: 12, height: 12)
            case .urgent:
                Circle()
                    .fill(.black.opacity(0.75))
                    .frame(width: 11, height: 15)
            }
        }
    }

    private var muzzle: some View {
        ZStack {
            Capsule()
                .fill(Color(red: 0.91, green: 0.80, blue: 0.67))
                .frame(width: 48, height: 30)

            VStack(spacing: 3) {
                Circle()
                    .fill(.black.opacity(0.72))
                    .frame(width: 8, height: 6)
                mouth
            }
        }
    }

    private var mouth: some View {
        Group {
            switch mood {
            case .calm:
                Smile()
                    .stroke(.black.opacity(0.62), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    .frame(width: 24, height: 10)
            case .alert:
                Circle()
                    .stroke(.black.opacity(0.62), lineWidth: 1.6)
                    .frame(width: 8, height: 8)
            case .urgent:
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(.black.opacity(0.62))
                    .frame(width: 13, height: 7)
            }
        }
    }
}

private struct Smile: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + 1))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + 1),
                control: CGPoint(x: rect.midX, y: rect.maxY)
            )
        }
    }
}
