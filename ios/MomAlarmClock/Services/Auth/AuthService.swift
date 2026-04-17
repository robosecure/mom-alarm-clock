import Foundation
import CryptoKit
import Security
import AuthenticationServices
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage

/// Manages authentication and role enforcement.
/// Uses Firebase Auth when Firebase is configured, falls back to local auth for development.
/// Roles are validated server-side — a child cannot become a parent by clearing local state.
@MainActor
@Observable
final class AuthService {
    private(set) var currentUser: AuthState?
    private(set) var isAuthenticated = false
    private(set) var isLoading = true
    private(set) var awaitingEmailVerification = false
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
    /// Sends a verification email — account stays inactive until verified.
    func signUpAsParent(email: String, password: String, displayName: String) async throws {
        let userID: String

        if isFirebaseAvailable {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            userID = result.user.uid

            // Send verification email before activating the account
            try await result.user.sendEmailVerification()
        } else {
            #if DEBUG
            // Local dev fallback — skip email verification in debug
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
        lastJoinCode = joinCode
        BetaDiagnostics.log(.pairingSuccess(role: "parent"))
        print("[Auth] Parent signed up. Family: \(familyID.prefix(8))...")

        // Check if email verification is required
        if isFirebaseAvailable, Auth.auth().currentUser?.isEmailVerified == false {
            awaitingEmailVerification = true
            isAuthenticated = false // Don't activate until verified
        } else {
            // Local dev or already verified (e.g., Sign in with Apple)
            awaitingEmailVerification = false
            isAuthenticated = true
        }
    }

    /// Resends the verification email to the current user.
    func resendVerificationEmail() async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await user.sendEmailVerification()
    }

    /// Checks if the user has verified their email. Call after they return from email.
    /// If verified, activates the account.
    func checkEmailVerification() async -> Bool {
        guard let user = Auth.auth().currentUser else { return false }
        try? await user.reload()
        if user.isEmailVerified {
            awaitingEmailVerification = false
            isAuthenticated = true
            return true
        }
        return false
    }

    /// The join code from the most recent signUp, so the UI can display it.
    private(set) var lastJoinCode: String?

    /// Current nonce for Sign in with Apple (must be set before starting the flow).
    private(set) var currentNonce: String?

    /// Generates a random nonce for Sign in with Apple.
    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return nonce
    }

    /// Completes Sign in with Apple after the user authorizes.
    /// Creates a new family if this is a first-time user, or restores an existing session.
    func signInWithApple(authorization: ASAuthorization) async throws {
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8),
              let nonce = currentNonce else {
            throw AuthError.notAuthenticated
        }

        guard isFirebaseAvailable else {
            throw AuthError.notAuthenticated
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: nonce,
            fullName: appleCredential.fullName
        )
        let result = try await Auth.auth().signIn(with: credential)
        let userID = result.user.uid
        let isNewUser = result.additionalUserInfo?.isNewUser ?? false

        // Extract display name from Apple credential (only provided on first sign-in)
        let displayName = [appleCredential.fullName?.givenName, appleCredential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        let finalName = displayName.isEmpty ? "Guardian" : displayName

        if isNewUser {
            // First-time Apple sign-in — create a new family
            let (familyID, joinCode) = try await syncService.createFamily(
                ownerUserID: userID,
                displayName: finalName
            )
            let state = AuthState(userID: userID, familyID: familyID, role: .parent, displayName: finalName)
            try await localStore.saveAuthState(state)
            currentUser = state
            isAuthenticated = true
            lastJoinCode = joinCode
            BetaDiagnostics.log(.pairingSuccess(role: "parent"))
            print("[Auth] Apple sign-in (new). Family: \(familyID.prefix(8))...")
        } else {
            // Returning user — restore session from Firestore
            guard let validatedState = try await syncService.validateRole(userID: userID) else {
                throw AuthError.invalidCredentials
            }
            try await localStore.saveAuthState(validatedState)
            currentUser = validatedState
            isAuthenticated = true
            print("[Auth] Apple sign-in (returning). Family: \(validatedState.familyID.prefix(8))...")
        }

        currentNonce = nil
    }

    /// Generates a cryptographically random nonce string for Sign in with Apple.
    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        precondition(status == errSecSuccess, "Failed to generate random nonce")
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

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

            // Check email verification FIRST — don't save auth state for unverified users
            if result.user.isEmailVerified {
                try await localStore.saveAuthState(validatedState)
                currentUser = validatedState
                awaitingEmailVerification = false
                isAuthenticated = true
            } else {
                // Sign out of Firebase immediately; verification screen handles re-check
                currentUser = validatedState // needed for EmailVerificationView to show email
                awaitingEmailVerification = true
                isAuthenticated = false
            }
        } else {
            #if DEBUG
            // Local dev fallback — check registered accounts (survives sign-out)
            if let saved = await localStore.findRegisteredAccount(email: email) {
                try await localStore.saveAuthState(saved)
                currentUser = saved
                isAuthenticated = true
            } else {
                throw AuthError.invalidCredentials
            }
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
        // Remember last role so the landing page can auto-open the right sign-in form
        if let role = currentUser?.role {
            UserDefaults.standard.set(role.rawValue, forKey: "lastSignedInRole")
        }
        if isFirebaseAvailable {
            try? Auth.auth().signOut()
        }
        await localStore.clearAuthState()
        currentUser = nil
        isAuthenticated = false
        awaitingEmailVerification = false
        lastJoinCode = nil
        // Clear device-scoped UI flags so the next user starts fresh
        UserDefaults.standard.removeObject(forKey: "hasSeenFirstCelebration")
    }

    /// Abandons an unverified signup: deletes the Firebase Auth user + family so
    /// the user can start over with the same email. Called by "Use a Different Email".
    func abandonUnverifiedSignup() async {
        guard awaitingEmailVerification else {
            await signOut()
            return
        }

        if isFirebaseAvailable, let firebaseUser = Auth.auth().currentUser {
            // Best-effort: delete the partially-created family and user doc
            if let familyID = currentUser?.familyID {
                let db = FirebaseFirestore.Firestore.firestore()
                try? await db.collection("families").document(familyID).delete()
                try? await db.collection("users").document(firebaseUser.uid).delete()
            }
            // Delete the Firebase Auth user so the email is freed up
            try? await firebaseUser.delete()
        }

        await localStore.clearAuthState()
        currentUser = nil
        isAuthenticated = false
        awaitingEmailVerification = false
        lastJoinCode = nil
        // Clear remembered role so landing page doesn't auto-open sign-in
        UserDefaults.standard.removeObject(forKey: "lastSignedInRole")
    }

    // MARK: - Account Deletion (App Store requirement)

    /// Deletes the user's Firebase Auth account and clears all local data.
    /// Firestore data (family, children, sessions) is left for the Cloud Function
    /// cleanup to handle — or can be manually deleted by a future admin tool.
    /// This satisfies Apple's account deletion requirement.
    func deleteAccount() async throws {
        guard let firebaseUser = Auth.auth().currentUser else {
            // No Firebase user — just clear local state
            await localStore.clearAuthState()
            currentUser = nil
            isAuthenticated = false
            return
        }

        if isFirebaseAvailable {
            let db = FirebaseFirestore.Firestore.firestore()

            // 1. Delete the user's Firestore document (users/{uid})
            try? await db.collection("users").document(firebaseUser.uid).delete()

            // 2. Cascade-delete the entire family.
            //    Product rule: "Delete guardian account = delete the whole family."
            //    The child devices can't function without a guardian, and orphaned data
            //    is a privacy liability. Best-effort — failures don't block account deletion.
            if let familyID = currentUser?.familyID, currentUser?.role == .parent {
                let familyRef = db.collection("families").document(familyID)
                let subcollections = ["children", "sessions", "tamperEvents", "pushLog", "ops"]
                for name in subcollections {
                    let snapshot = try? await familyRef.collection(name).limit(to: 500).getDocuments()
                    if let docs = snapshot?.documents {
                        let batch = db.batch()
                        for doc in docs { batch.deleteDocument(doc.reference) }
                        try? await batch.commit()
                    }
                }
                // Delete any family join codes
                let codes = try? await db.collection("familyCodes")
                    .whereField("familyID", isEqualTo: familyID).limit(to: 10).getDocuments()
                if let codeDocs = codes?.documents {
                    let batch = db.batch()
                    for doc in codeDocs { batch.deleteDocument(doc.reference) }
                    try? await batch.commit()
                }
                // Delete voice alarm storage files (best-effort)
                if FirebaseApp.app() != nil {
                    let storage = FirebaseStorage.Storage.storage()
                    let voiceRef = storage.reference().child("families/\(familyID)")
                    try? await voiceRef.delete()
                }
                // Delete the family document itself
                try? await familyRef.delete()
            }
        }

        // 3. Delete the Firebase Auth account
        try await firebaseUser.delete()

        // 4. Clear all local data
        await localStore.clearAuthState()
        await localStore.clearQueue()

        currentUser = nil
        isAuthenticated = false
        lastJoinCode = nil
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
