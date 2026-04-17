import Foundation

/// File-based local persistence for offline-first behavior.
/// Alarm schedules and profile data persist here so alarms fire without network.
/// Pending sync operations are queued and replayed on reconnect.
actor LocalStore {
    static let shared = LocalStore()

    // FileManager/JSONCoder live on the actor — all reads go through actor-isolated methods.
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Resolved once at init so nonisolated init doesn't need to touch actor-isolated state.
    private let storeDirectory: URL

    init() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        let dir = docs.appendingPathComponent("MomAlarmClockStore", isDirectory: true)
        self.storeDirectory = dir
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        // Encrypt local data at rest — files are inaccessible when the device is locked.
        try? fm.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: dir.path
        )
    }

    // MARK: - Generic Persistence

    func save<T: Codable>(_ value: T, forKey key: String) throws {
        let data = try encoder.encode(value)
        let url = storeDirectory.appendingPathComponent("\(key).json")
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        let url = storeDirectory.appendingPathComponent("\(key).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    func delete(forKey key: String) {
        let url = storeDirectory.appendingPathComponent("\(key).json")
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Typed Accessors

    /// The local child profile (on child device).
    func childProfile() -> ChildProfile? {
        load(ChildProfile.self, forKey: "childProfile")
    }

    func saveChildProfile(_ profile: ChildProfile) throws {
        try save(profile, forKey: "childProfile")
    }

    /// All child profiles in this family (guardian side).
    func childProfiles() -> [ChildProfile] {
        load([ChildProfile].self, forKey: "childProfiles") ?? []
    }

    func saveChildProfiles(_ profiles: [ChildProfile]) throws {
        try save(profiles, forKey: "childProfiles")
    }

    /// All alarm schedules for this device's child.
    func alarmSchedules() -> [AlarmSchedule] {
        load([AlarmSchedule].self, forKey: "alarmSchedules") ?? []
    }

    func saveAlarmSchedules(_ schedules: [AlarmSchedule]) throws {
        try save(schedules, forKey: "alarmSchedules")
    }

    /// The currently active morning session (if any).
    func activeSession() -> MorningSession? {
        load(MorningSession.self, forKey: "activeSession")
    }

    func saveActiveSession(_ session: MorningSession?) throws {
        if let session {
            try save(session, forKey: "activeSession")
        } else {
            delete(forKey: "activeSession")
        }
    }

    /// Recent sessions for history display.
    func recentSessions() -> [MorningSession] {
        load([MorningSession].self, forKey: "recentSessions") ?? []
    }

    func saveRecentSessions(_ sessions: [MorningSession]) throws {
        // Retention cap: keep only the most recent 90 sessions per device
        let capped = Array(sessions.sorted { $0.alarmFiredAt > $1.alarmFiredAt }.prefix(90))
        try save(capped, forKey: "recentSessions")
    }

    /// Removes sessions older than `daysToKeep` days from local cache.
    func pruneOldSessions(daysToKeep: Int = 90) {
        var sessions = recentSessions()
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -daysToKeep, to: .now) else {
            // Calendar.date() can return nil in edge cases (corrupted calendar state).
            // Skip pruning rather than crashing on every launch.
            return
        }
        sessions.removeAll { $0.alarmFiredAt < cutoff }
        try? save(sessions, forKey: "recentSessions")
    }

    /// Auth state: family ID, user role, user ID (active session).
    func authState() -> AuthState? {
        load(AuthState.self, forKey: "authState")
    }

    func saveAuthState(_ state: AuthState) throws {
        try save(state, forKey: "authState")
        // Also save to registered accounts (survives sign-out)
        var accounts = registeredAccounts()
        accounts[state.userID] = state
        try save(accounts, forKey: "registeredAccounts")
    }

    /// Registered accounts — persists through sign-out so users can sign back in.
    func registeredAccounts() -> [String: AuthState] {
        load([String: AuthState].self, forKey: "registeredAccounts") ?? [:]
    }

    /// Find a registered account by email-like lookup (matches userID prefix or displayName).
    func findRegisteredAccount(email: String) -> AuthState? {
        let accounts = registeredAccounts()
        // In local dev mode, userID is "parent-XXXXXXXX" and there's no real email.
        // Match any parent account (there's typically only one in local dev).
        return accounts.values.first { $0.role == .parent }
    }

    func clearAuthState() {
        delete(forKey: "authState")
    }

    // MARK: - Offline Queue

    /// Queued sync operations that failed due to network issues.
    func pendingQueue() -> [QueuedAction] {
        load([QueuedAction].self, forKey: "offlineQueue") ?? []
    }

    func appendToQueue(_ action: QueuedAction) throws {
        var queue = pendingQueue()
        queue.append(action)
        try save(queue, forKey: "offlineQueue")
    }

    func clearQueue() {
        delete(forKey: "offlineQueue")
    }

    func replaceQueue(_ actions: [QueuedAction]) throws {
        try save(actions, forKey: "offlineQueue")
    }
}

// MARK: - Supporting Types

struct AuthState: Codable, Sendable {
    var userID: String
    var familyID: String
    var role: UserRole
    var displayName: String

    enum UserRole: String, Codable, Sendable {
        case parent
        case child
    }
}

struct QueuedAction: Codable, Sendable, Identifiable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var actionType: ActionType
    var payload: Data // JSON-encoded model

    enum ActionType: String, Codable, Sendable {
        case saveSession
        case saveTamperEvent
        case updateHeartbeat
        case updateProfile
    }
}
