import Foundation

/// Local-only SyncService implementation for development and offline fallback.
/// Uses LocalStore for persistence and NotificationCenter for "real-time" observation.
/// This allows the app to compile and run without Firebase configured.
final class LocalSyncService: SyncService, @unchecked Sendable {
    private let store = LocalStore.shared

    // Internal storage keyed by familyID
    fileprivate actor Storage {
        var families: [String: FamilyData] = [:]
        var users: [String: AuthState] = [:]
        var familyCodes: [String: String] = [:] // code → familyID

        struct FamilyData {
            var children: [ChildProfile] = []
            var alarms: [AlarmSchedule] = []
            var sessions: [MorningSession] = []
            var tamperEvents: [TamperEvent] = []
        }

        func family(_ id: String) -> FamilyData {
            families[id] ?? FamilyData()
        }

        func ensureFamily(_ id: String) {
            if families[id] == nil {
                families[id] = FamilyData()
            }
        }
    }

    fileprivate let storage = Storage()

    // MARK: - Family

    func createFamily(ownerUserID: String, displayName: String) async throws -> (familyID: String, joinCode: String) {
        let familyID = UUID().uuidString
        let code = generateJoinCode()
        await storage.ensureFamily(familyID)
        await storage.setCodes(code: code, familyID: familyID)
        let state = AuthState(userID: ownerUserID, familyID: familyID, role: .parent, displayName: displayName)
        await storage.setUser(ownerUserID, state: state)
        try await store.saveAuthState(state)
        return (familyID, code)
    }

    func joinFamily(code: String, userID: String, displayName: String, role: AuthState.UserRole) async throws -> String {
        guard let familyID = await storage.getCode(code.uppercased()) else {
            throw SyncError.invalidJoinCode
        }
        let state = AuthState(userID: userID, familyID: familyID, role: role, displayName: displayName)
        await storage.setUser(userID, state: state)
        try await store.saveAuthState(state)
        return familyID
    }

    func validateRole(userID: String) async throws -> AuthState? {
        if let state = await storage.getUser(userID) { return state }
        return await store.authState()
    }

    // MARK: - Child Profiles

    func saveChildProfile(_ profile: ChildProfile, familyID: String) async throws {
        await storage.upsertChild(profile, familyID: familyID)
        notify("children-\(familyID)")
    }

    func fetchChildProfiles(familyID: String) async throws -> [ChildProfile] {
        await storage.family(familyID).children
    }

    func observeChildProfiles(familyID: String) -> AsyncStream<[ChildProfile]> {
        observeNotification("children-\(familyID)") { [storage] in
            await storage.family(familyID).children
        }
    }

    // MARK: - Alarm Schedules

    func saveAlarmSchedule(_ schedule: AlarmSchedule, familyID: String) async throws {
        await storage.upsertAlarm(schedule, familyID: familyID)
        // Also persist locally for offline alarm firing
        let allAlarms = await storage.family(familyID).alarms
        try await store.saveAlarmSchedules(allAlarms)
        notify("alarms-\(familyID)")
    }

    func deleteAlarmSchedule(_ scheduleID: UUID, familyID: String) async throws {
        await storage.removeAlarm(scheduleID, familyID: familyID)
        let allAlarms = await storage.family(familyID).alarms
        try await store.saveAlarmSchedules(allAlarms)
        notify("alarms-\(familyID)")
    }

    func fetchAlarmSchedules(familyID: String, childID: UUID) async throws -> [AlarmSchedule] {
        await storage.family(familyID).alarms.filter { $0.childProfileID == childID }
    }

    func observeAlarmSchedules(familyID: String, childID: UUID) -> AsyncStream<[AlarmSchedule]> {
        observeNotification("alarms-\(familyID)") { [storage] in
            await storage.family(familyID).alarms.filter { $0.childProfileID == childID }
        }
    }

    // MARK: - Morning Sessions

    func saveSession(_ session: MorningSession, familyID: String) async throws {
        await storage.upsertSession(session, familyID: familyID)
        try await store.saveActiveSession(session.isActive ? session : nil)
        notify("sessions-\(familyID)")
        notify("session-\(session.id.uuidString)")
    }

    func fetchSessions(familyID: String, childID: UUID, since: Date) async throws -> [MorningSession] {
        await storage.family(familyID).sessions
            .filter { $0.childProfileID == childID && $0.alarmFiredAt >= since }
            .sorted { $0.alarmFiredAt > $1.alarmFiredAt }
    }

    func observeActiveSessions(familyID: String, childID: UUID) -> AsyncStream<[MorningSession]> {
        observeNotification("sessions-\(familyID)") { [storage] in
            await storage.family(familyID).sessions
                .filter { $0.childProfileID == childID && $0.isActive }
        }
    }

    func observeSession(familyID: String, sessionID: UUID) -> AsyncStream<MorningSession?> {
        observeNotification("session-\(sessionID.uuidString)") { [storage] in
            await storage.family(familyID).sessions.first { $0.id == sessionID }
        }
    }

    // MARK: - Tamper Events

    func saveTamperEvent(_ event: TamperEvent, familyID: String) async throws {
        await storage.appendTamperEvent(event, familyID: familyID)
        notify("tamper-\(familyID)")
    }

    func fetchTamperEvents(familyID: String, childID: UUID, since: Date) async throws -> [TamperEvent] {
        await storage.family(familyID).tamperEvents
            .filter { $0.childProfileID == childID && $0.timestamp >= since }
            .sorted { $0.timestamp > $1.timestamp }
    }

    func observeTamperEvents(familyID: String, childID: UUID) -> AsyncStream<[TamperEvent]> {
        observeNotification("tamper-\(familyID)") { [storage] in
            await storage.family(familyID).tamperEvents
                .filter { $0.childProfileID == childID }
                .sorted { $0.timestamp > $1.timestamp }
        }
    }

    // MARK: - Atomic Operations

    func escalateSessionAndProfile(session: MorningSession, profile: ChildProfile, familyID: String) async throws {
        // Local implementation: sequential writes (no Firestore batch needed)
        try await saveSession(session, familyID: familyID)
        try await saveChildProfile(profile, familyID: familyID)
    }

    // MARK: - Heartbeat

    func updateHeartbeat(familyID: String, childID: UUID) async throws {
        var children = await storage.family(familyID).children
        if let idx = children.firstIndex(where: { $0.id == childID }) {
            children[idx].lastHeartbeat = Date()
            await storage.setChildren(children, familyID: familyID)
            notify("children-\(familyID)")
        }
    }

    // MARK: - Helpers

    private func generateJoinCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    private func notify(_ name: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name(name), object: nil)
        }
    }

    private func observeNotification<T: Sendable>(_ name: String, fetch: @escaping @Sendable () async -> T) -> AsyncStream<T> {
        AsyncStream { continuation in
            // Yield current value immediately
            Task {
                let value = await fetch()
                continuation.yield(value)
            }

            let observer = NotificationCenter.default.addObserver(
                forName: Notification.Name(name),
                object: nil,
                queue: .main
            ) { _ in
                Task {
                    let value = await fetch()
                    continuation.yield(value)
                }
            }

            continuation.onTermination = { _ in
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}

// MARK: - Storage Actor Mutations

// MARK: - Storage Actor Helpers

extension LocalSyncService.Storage {
    func setCodes(code: String, familyID: String) {
        familyCodes[code] = familyID
    }

    func getCode(_ code: String) -> String? {
        familyCodes[code]
    }

    func setUser(_ id: String, state: AuthState) {
        users[id] = state
    }

    func getUser(_ id: String) -> AuthState? {
        users[id]
    }

    func upsertChild(_ profile: ChildProfile, familyID: String) {
        ensureFamily(familyID)
        if let idx = families[familyID]!.children.firstIndex(where: { $0.id == profile.id }) {
            families[familyID]!.children[idx] = profile
        } else {
            families[familyID]!.children.append(profile)
        }
    }

    func setChildren(_ children: [ChildProfile], familyID: String) {
        ensureFamily(familyID)
        families[familyID]!.children = children
    }

    func upsertAlarm(_ schedule: AlarmSchedule, familyID: String) {
        ensureFamily(familyID)
        if let idx = families[familyID]!.alarms.firstIndex(where: { $0.id == schedule.id }) {
            families[familyID]!.alarms[idx] = schedule
        } else {
            families[familyID]!.alarms.append(schedule)
        }
    }

    func removeAlarm(_ id: UUID, familyID: String) {
        families[familyID]?.alarms.removeAll { $0.id == id }
    }

    func upsertSession(_ session: MorningSession, familyID: String) {
        ensureFamily(familyID)
        if let idx = families[familyID]!.sessions.firstIndex(where: { $0.id == session.id }) {
            families[familyID]!.sessions[idx] = session
        } else {
            families[familyID]!.sessions.append(session)
        }
    }

    func appendTamperEvent(_ event: TamperEvent, familyID: String) {
        ensureFamily(familyID)
        families[familyID]!.tamperEvents.append(event)
    }
}
