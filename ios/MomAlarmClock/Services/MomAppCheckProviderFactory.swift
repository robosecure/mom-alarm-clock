import FirebaseAppCheck
import FirebaseCore

/// Production App Check provider factory.
/// Uses App Attest (Secure Enclave) on real devices, falls back to DeviceCheck on older devices.
final class MomAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
        if #available(iOS 14.0, *) {
            return AppAttestProvider(app: app)
        }
        return DeviceCheckProvider(app: app)
    }
}
