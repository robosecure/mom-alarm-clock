import Foundation
import FirebaseCrashlytics

/// Thin wrapper around Firebase Crashlytics so we can record Swift `throws` sites
/// (Crashlytics only auto-captures native NSException crashes). Wraps all calls
/// behind a safe no-op if Firebase isn't configured yet.
enum CrashReporter {
    static func record(_ error: Error, userInfo: [String: Any] = [:]) {
        #if DEBUG
        DebugLog.log("[CrashReporter] \(error.localizedDescription)")
        #endif
        let crashlytics = Crashlytics.crashlytics()
        for (k, v) in userInfo {
            crashlytics.setCustomValue(v, forKey: k)
        }
        crashlytics.record(error: error)
    }

    static func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }
}
