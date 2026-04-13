import Foundation
import CryptoKit
import Security
import FirebaseAuth
import FirebaseCore

/// Manages authentication and role enforcement.
/// Uses Firebase Auth when Firebase is configured, falls back to local auth for development.
/// Roles are validated server-side — a child cannot become a parent by clearing local state.
@Observable
final class AuthService {
    private(set) var currentUser: AuthState?
    private(set) var isAuthenticated = false
    private(set) var isLoading = true
    var error: String?

    private let syncService: any SyncService
    private let localStore = LocalStore.shared

    /// Whether Firebase Auth is available (Firebase was configured in AppDelegate).
    private var isFirebaseAvailable: Bool {
        FirebaseApp.app() != nil
    }

    init(syncService: any SyncService) {
        self.syncService = syncService
    }

    // MARK: - Session Restoration

    /// Attempts to restore a previous session.
    /// Firebase path: checks Auth.auth().currentUser, then validates role in Firestore.
    /// Local path: reads from LocalStore, validates against sync service.
    func restoreSession() async {
        isLoading = true
        defer { isLoading = false }

        if isFirebaseAvailable, let firebaseUser = Auth.auth().currentUser {
            // Firebase user exists — validate their role in Firestore
            do {
                if let validatedState = try await syncService.validateRole(userID: firebaseUser.uid) {
                    currentUser = validatedState
                    isAuthenticated = true
                    try? await localStore.saveAuthState(validatedState)
                    return
                }
                // validateRole returned nil — user doesn't exist in Firestore
                try? Auth.auth().signOut()
                await localStore.clearAuthState()
                isAuthenticated = false
                return
            } catch {
                // Network error — allow cached child state for offline alarm firing,
                // but never grant cached parent authority without server validation.
                if let savedState = await localStore.authState(), savedState.role == .child {
                    currentUser = savedState
                    isAuthenticated = true
                    return
                }
                // Parent role requires online validation — fail closed
                isAuthenticated = false
                self.error = "Cannot verify parent account offline. Please check your connection."
                return
            }
        }

        // No Firebase user — check for stale local state
        if isFirebaseAvailable && Auth.auth().currentUser == nil {
            await localStore.clearAuthState()
            isAuthenticated = false
            return
        }

        #if DEBUG
        // Local-only development mode
        if let savedState = await localStore.authState() {
            currentUser = savedState
            isAuthenticated = true
            return
        }
        #endif

        isAuthenticated = false
    }

    // MARK: - Parent Auth

    /// Creates a new parent account and family.
    func signUpAsParent(email: String, password: String, displayName: String) async throws {
        let userID: String

        if isFirebaseAvailable {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            userID = result.user.uid
        } else {
            #if DEBUG
            // Local dev fallback — only available in debug builds
            userID = "parent-\(UUID().uuidString.prefix(8))"
            #else
            throw AuthError.notAuthenticated
            #endif
        }

        let (familyID, joinCode) = try await syncService.createFamily(
            ownerUserID: userID,
            displayName: displayName
        )

        let state = AuthState(userID: userID, familyID: familyID, role: .parent, displayName: displayName)
        try await localStore.saveAuthState(state)
        currentUser = state
        isAuthenticated = true

        // Store the join code so ParentAuthView can display it
        _lastJoinCode = joinCode
        BetaDiagnostics.log(.pairingSuccess(role: "parent"))
        print("[Auth] Parent signed up. Family: \(familyID), Join code: \(joinCode)")
    }

    /// The join code from the most recent signUp, so the UI can display it.
    private(set) var _lastJoinCode: String?

    /// Signs in an existing parent.
    func signInAsParent(email: String, password: String) async throws {
        let userID: String

        if isFirebaseAvailable {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            userID = result.user.uid

            // Validate that this user is actually a parent in Firestore
            guard let validatedState = try await syncService.validateRole(userID: userID) else {
                try Auth.auth().signOut()
                throw AuthError.invalidCredentials
            }
            guard validatedState.role == .parent else {
                try Auth.auth().signOut()
                throw AuthError.invalidCredentials
            }

            try await localStore.saveAuthState(validatedState)
            currentUser = validatedState
            isAuthenticated = true
        } else {
            #if DEBUG
            // Local dev fallback — only available in debug builds
            guard let saved = await localStore.authState(), saved.role == .parent else {
                throw AuthError.invalidCredentials
            }
            currentUser = saved
            isAuthenticated = true
            #else
            throw AuthError.notAuthenticated
            #endif
        }
    }

    // MARK: - Child Auth

    /// Pairs a child device using a family join code.
    /// Firebase path: creates an anonymous auth account, then joins the family in Firestore.
    /// Local path: creates a local user ID, joins via LocalSyncService.
    func pairAsChild(familyCode: String, displayName: String) async throws {
        let userID: String

        if isFirebaseAvailable {
            let result = try await Auth.auth().signInAnonymously()
            userID = result.user.uid
        } else {
            #if DEBUG
            userID = "child-\(UUID().uuidString.prefix(8))"
            #else
            throw AuthError.notAuthenticated
            #endif
        }

        let familyID = try await syncService.joinFamily(
            code: familyCode,
            userID: userID,
            displayName: displayName,
            role: .child
        )

        let state = AuthState(userID: userID, familyID: familyID, role: .child, displayName: displayName)
        try await localStore.saveAuthState(state)
        currentUser = state
        isAuthenticated = true

        BetaDiagnostics.log(.pairingSuccess(role: "child"))
        print("[Auth] Child paired to family: \(familyID)")
    }

    // MARK: - Sign Out

    func signOut() async {
        if isFirebaseAvailable {
            try? Auth.auth().signOut()
        }
        await localStore.clearAuthState()
        currentUser = nil
        isAuthenticated = false
        _lastJoinCode = nil
    }

    // MARK: - Parent PIN

    /// Sets a 4-6 digit PIN for parent-protected actions.
    func setParentPIN(_ pin: String) throws {
        let salt = UUID().uuidString
        let hash = sha256("\(pin):\(salt)")
        let data = "\(salt):\(hash)".data(using: .utf8)!
        try saveToKeychain(data: data, key: "com.momclock.parentPIN")
    }

    /// Verifies the parent PIN.
    func verifyParentPIN(_ pin: String) -> Bool {
        guard let stored = loadFromKeychain(key: "com.momclock.parentPIN"),
              let str = String(data: stored, encoding: .utf8) else {
            return false
        }
        let parts = str.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return false }
        let salt = String(parts[0])
        let expectedHash = String(parts[1])
        return sha256("\(pin):\(salt)") == expectedHash
    }

    /// Whether a parent PIN has been set.
    var hasParentPIN: Bool {
        loadFromKeychain(key: "com.momclock.parentPIN") != nil
    }

    // MARK: - Helpers

    private func sha256(_ input: String) -> String {
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func saveToKeychain(data: Data, key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AuthError.keychainError
        }
    }

    private func loadFromKeychain(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case invalidCredentials
    case notAuthenticated
    case keychainError
    case familyNotFound

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: "Invalid email or password."
        case .notAuthenticated:   "Not signed in."
        case .keychainError:      "Failed to save secure data."
        case .familyNotFound:     "Family not found."
        }
    }
}
