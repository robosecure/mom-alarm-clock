import Foundation

/// Backend-agnostic sync protocol. All ViewModels and services depend on this,
/// never on a concrete backend. Implementations: FirestoreSyncService, LocalSyncService.
protocol SyncService: Sendable {
    // MARK: - Family

    /// Creates a new family and returns its ID + join code.
    func createFamily(ownerUserID: String, displayName: String) async throws -> (familyID: String, joinCode: String)

    /// Joins an existing family using a join code. Returns the family ID.
    func joinFamily(code: String, userID: String, displayName: String, role: AuthState.UserRole) async throws -> String

    /// Validates that a user belongs to a family and returns their role.
    func validateRole(userID: String) async throws -> AuthState?

    // MARK: - Child Profiles

    func saveChildProfile(_ profile: ChildProfile, familyID: String) async throws
    func fetchChildProfiles(familyID: String) async throws -> [ChildProfile]
    func observeChildProfiles(familyID: String) -> AsyncStream<[ChildProfile]>

    /// Deletes a child profile document. Server-side Cloud Function
    /// `cleanupOnChildDelete` cascades to alarms/sessions/tamperEvents.
    func deleteChildProfile(_ childID: UUID, familyID: String) async throws

    // MARK: - Alarm Schedules

    func saveAlarmSchedule(_ schedule: AlarmSchedule, familyID: String) async throws
    func deleteAlarmSchedule(_ scheduleID: UUID, familyID: String) async throws
    func fetchAlarmSchedules(familyID: String, childID: UUID) async throws -> [AlarmSchedule]
    func observeAlarmSchedules(familyID: String, childID: UUID) -> AsyncStream<[AlarmSchedule]>

    // MARK: - Morning Sessions

    func saveSession(_ session: MorningSession, familyID: String) async throws
    func fetchSessions(familyID: String, childID: UUID, since: Date) async throws -> [MorningSession]
    func observeActiveSessions(familyID: String, childID: UUID) -> AsyncStream<[MorningSession]>
    /// Observe a single session for real-time updates (e.g., waiting for parent action).
    func observeSession(familyID: String, sessionID: UUID) -> AsyncStream<MorningSession?>

    // MARK: - Tamper Events

    func saveTamperEvent(_ event: TamperEvent, familyID: String) async throws
    func fetchTamperEvents(familyID: String, childID: UUID, since: Date) async throws -> [TamperEvent]
    func observeTamperEvents(familyID: String, childID: UUID) -> AsyncStream<[TamperEvent]>

    // MARK: - Atomic Operations

    /// Atomically updates a session AND a child profile together (e.g., escalation).
    /// Firestore uses a batch write; local implementation writes both sequentially.
    func escalateSessionAndProfile(session: MorningSession, profile: ChildProfile, familyID: String) async throws

    // MARK: - Heartbeat

    func updateHeartbeat(familyID: String, childID: UUID) async throws
}

// MARK: - Sync Errors

/// Shared error type for sync operations, used by all SyncService implementations.
enum SyncError: LocalizedError {
    case invalidJoinCode
    case joinCodeExpired
    case joinCodeAlreadyUsed
    case familyNotFound
    case notAuthenticated
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidJoinCode:      "Invalid family join code."
        case .joinCodeExpired:      "This join code has expired. Ask the parent for a new one."
        case .joinCodeAlreadyUsed:  "This join code has already been used."
        case .familyNotFound:       "Family not found."
        case .notAuthenticated:     "Not authenticated."
        case .encodingFailed:       "Failed to encode data."
        }
    }
}

// MARK: - Write Rejection Classification

/// Structured error for classifying why a Firestore write was rejected.
/// Used by NetworkMonitor to decide whether to drop or re-queue actions.
enum SyncWriteFailure: Error, Sendable {
    /// Firestore rules rejected: version guard, field-level, or state transition.
    case rulesRejected(reason: String)
    /// Auth token expired or invalid.
    case authExpired
    /// Transient network issue — safe to retry.
    case transientNetwork(underlying: Error)
    /// Unknown error — safe to retry.
    case unknown(underlying: Error)

    /// Whether the action should be dropped (not re-queued).
    var shouldDrop: Bool {
        switch self {
        case .rulesRejected: true
        case .authExpired: false
        case .transientNetwork: false
        case .unknown: false
        }
    }

    var displayReason: String {
        switch self {
        case .rulesRejected(let reason): "Rules rejected: \(reason)"
        case .authExpired: "Auth expired"
        case .transientNetwork: "Network error (will retry)"
        case .unknown(let err): "Unknown: \(err.localizedDescription)"
        }
    }
}
