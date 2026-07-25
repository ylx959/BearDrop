import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var isBearVisible: Bool {
        didSet { UserDefaults.standard.set(isBearVisible, forKey: Keys.isBearVisible) }
    }

    @Published var alertThresholdMinutes: Double {
        didSet { UserDefaults.standard.set(alertThresholdMinutes, forKey: Keys.alertThresholdMinutes) }
    }

    @Published var urgentThresholdMinutes: Double {
        didSet { UserDefaults.standard.set(urgentThresholdMinutes, forKey: Keys.urgentThresholdMinutes) }
    }

    @Published var animationIntensity: Double {
        didSet { UserDefaults.standard.set(animationIntensity, forKey: Keys.animationIntensity) }
    }

    @Published var plannedFlightSpeed: PlannedFlightSpeed {
        didSet { UserDefaults.standard.set(plannedFlightSpeed.rawValue, forKey: Keys.plannedFlightSpeed) }
    }

    init() {
        isBearVisible = UserDefaults.standard.object(forKey: Keys.isBearVisible) as? Bool ?? true
        alertThresholdMinutes = UserDefaults.standard.object(forKey: Keys.alertThresholdMinutes) as? Double ?? 15
        urgentThresholdMinutes = UserDefaults.standard.object(forKey: Keys.urgentThresholdMinutes) as? Double ?? 5
        animationIntensity = UserDefaults.standard.object(forKey: Keys.animationIntensity) as? Double ?? 1
        let speedValue = UserDefaults.standard.string(forKey: Keys.plannedFlightSpeed) ?? PlannedFlightSpeed.fast.rawValue
        plannedFlightSpeed = PlannedFlightSpeed(rawValue: speedValue) ?? .fast
    }

    private enum Keys {
        static let isBearVisible = "isBearVisible"
        static let alertThresholdMinutes = "alertThresholdMinutes"
        static let urgentThresholdMinutes = "urgentThresholdMinutes"
        static let animationIntensity = "animationIntensity"
        static let plannedFlightSpeed = "plannedFlightSpeed"
    }
}
