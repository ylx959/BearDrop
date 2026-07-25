import Foundation

enum BearMood: Equatable {
    case calm
    case alert
    case urgent

    var face: String {
        switch self {
        case .calm: "smile"
        case .alert: "alert"
        case .urgent: "urgent"
        }
    }

    var motionMultiplier: Double {
        switch self {
        case .calm: 1
        case .alert: 1.25
        case .urgent: 1.55
        }
    }
}
