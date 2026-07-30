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

    @Published var windStyle: WindStyle {
        didSet { UserDefaults.standard.set(windStyle.rawValue, forKey: Keys.windStyle) }
    }

    @Published var plannedFlightSpeed: PlannedFlightSpeed {
        didSet { UserDefaults.standard.set(plannedFlightSpeed.rawValue, forKey: Keys.plannedFlightSpeed) }
    }

    /// The rig's own colour scheme, which has nothing to do with the system appearance — see
    /// `RigAppearance`.
    @Published var appearance: RigAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    init() {
        isBearVisible = UserDefaults.standard.object(forKey: Keys.isBearVisible) as? Bool ?? true
        alertThresholdMinutes = UserDefaults.standard.object(forKey: Keys.alertThresholdMinutes) as? Double ?? 15
        urgentThresholdMinutes = UserDefaults.standard.object(forKey: Keys.urgentThresholdMinutes) as? Double ?? 5
        animationIntensity = UserDefaults.standard.object(forKey: Keys.animationIntensity) as? Double ?? 1
        let windStyleValue = UserDefaults.standard.string(forKey: Keys.windStyle) ?? WindStyle.windy.rawValue
        windStyle = WindStyle(rawValue: windStyleValue) ?? .windy
        let speedValue = UserDefaults.standard.string(forKey: Keys.plannedFlightSpeed) ?? PlannedFlightSpeed.fast.rawValue
        plannedFlightSpeed = PlannedFlightSpeed(rawValue: speedValue) ?? .fast
        let appearanceValue = UserDefaults.standard.string(forKey: Keys.appearance) ?? RigAppearance.dark.rawValue
        appearance = RigAppearance(rawValue: appearanceValue) ?? .dark
    }

    private enum Keys {
        static let isBearVisible = "isBearVisible"
        static let alertThresholdMinutes = "alertThresholdMinutes"
        static let urgentThresholdMinutes = "urgentThresholdMinutes"
        static let animationIntensity = "animationIntensity"
        static let windStyle = "windStyle"
        static let plannedFlightSpeed = "plannedFlightSpeed"
        static let appearance = "appearance"
    }
}
