import AppKit
import ServiceManagement

/// Whether ParaBear starts itself when you log in.
///
/// **The system is the store, not `SettingsStore`.** Every other preference here is ours alone and
/// lives in `UserDefaults`; this one is a registration held by `launchd`, and the user can revoke
/// it from **System Settings → General → Login Items** without the app ever running. A mirrored
/// copy in `UserDefaults` would be a second answer free to disagree with the real one, and the
/// menu would go on claiming the bear opens at login long after macOS stopped opening it. So the
/// switch is drawn from `SMAppService.mainApp.status` and re-read every time the menu opens.
///
/// For the same reason `setEnabled` returns what the system says *afterwards* rather than whether
/// the call threw: registering can succeed and still land in `.requiresApproval` (the user turned
/// ParaBear off in Login Items, and only they can turn it back on), which is a request that did not
/// take. The caller shows the answer, never the intent.
enum LoginItem {
    /// `SMAppService` registers a *bundle*, so there is nothing for it to point `launchd` at when
    /// ParaBear is the bare executable `swift run` builds — the same boundary EventKit draws.
    /// Stated up front because the alternative is a switch that flicks back with no reason given.
    static var isAvailable: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// The one failure the user can do something about: the registration exists, but Login Items
    /// has it switched off.
    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    /// - Returns: whether ParaBear opens at login *now* — which is not always what was asked for.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Nothing to report that the state does not already say: the switch is about to be set
            // from `isEnabled`, so a throw shows up as the switch refusing to move.
        }

        return isEnabled
    }

    /// Where the user has to go when the answer is `needsApproval`. macOS deliberately does not let
    /// an app talk itself back out of that list.
    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
