import Foundation

enum WindStyle: String, CaseIterable, Identifiable {
    case calm
    case breezy
    case windy
    case stormy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calm: "Calm"
        case .breezy: "Breezy"
        case .windy: "Windy"
        case .stormy: "Stormy"
        }
    }

    var lateralMultiplier: Double {
        switch self {
        case .calm: 0.45
        case .breezy: 0.72
        case .windy: 1
        case .stormy: 1.28
        }
    }

    var verticalMultiplier: Double {
        switch self {
        case .calm: 0.55
        case .breezy: 0.78
        case .windy: 1
        case .stormy: 1.22
        }
    }

    var rotationMultiplier: Double {
        switch self {
        case .calm: 0.5
        case .breezy: 0.76
        case .windy: 1
        case .stormy: 1.2
        }
    }
}
