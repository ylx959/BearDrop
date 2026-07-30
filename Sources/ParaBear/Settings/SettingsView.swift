import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section("Bear") {
                Toggle("Enable reminder flights", isOn: $settings.isBearVisible)
                Picker("Planned speed", selection: $settings.plannedFlightSpeed) {
                    ForEach(PlannedFlightSpeed.allCases) { speed in
                        Text(speed.title).tag(speed)
                    }
                }
                .pickerStyle(.segmented)
                Slider(value: $settings.animationIntensity, in: 0.4...1.6) {
                    Text("Animation")
                }
                Picker("Wind", selection: $settings.windStyle) {
                    ForEach(WindStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Timing") {
                Stepper(value: $settings.alertThresholdMinutes, in: 6...60, step: 1) {
                    Text("Alert mood: \(Int(settings.alertThresholdMinutes)) minutes before")
                }
                Stepper(value: $settings.urgentThresholdMinutes, in: 1...15, step: 1) {
                    Text("Urgent mood: \(Int(settings.urgentThresholdMinutes)) minutes before")
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 420)
    }
}
