import Foundation

enum PlannedFlightSpeed: String, CaseIterable, Identifiable {
    case slow
    case normal
    case fast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .slow: "Slow"
        case .normal: "Normal"
        case .fast: "Fast"
        }
    }

    var flightDuration: TimeInterval {
        switch self {
        case .slow: 34
        case .normal: 26
        case .fast: 18
        }
    }
}
