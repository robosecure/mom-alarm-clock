import Foundation
import FirebaseFirestore

/// Firestore implementation of SyncService.
/// Collection structure:
///   families/{familyID}/children/{childID}
///   families/{familyID}/alarms/{alarmID}
///   families/{familyID}/sessions/{sessionID}
///   families/{familyID}/tamperEvents/{eventID}
///   users/{userID} → { role, familyID, displayName }
///   familyCodes/{code} → { familyID }
final class FirestoreSyncService: SyncService, @unchecked Sendable {
    private let db = Firestore.firestore()
    private let encoder: Firestore.Encoder = .init()
    private let decoder: Firestore.Decoder = .init()

    // MARK: - Family

    func createFamily(ownerUserID: String, displayName: String) async throws -> (familyID: String, joinCode: String) {
        let familyRef = db.collection("families").document()
        let code = generateJoinCode()

        let familyData: [String: Any] = [
            "ownerUserID": ownerUserID,
            "createdAt": FieldValue.serverTimestamp()
        ]
        try await familyRef.setData(familyData)

        // Store user record FIRST so security rules can validate role
        // (familyCodes create rule calls getUserData() which needs this doc)
        try await db.collection("users").document(ownerUserID).setData([
            "familyID": familyRef.documentID,
            "role": "parent",
            "displayName": displayName
        ])

        // Store join code with expiry (24 hours) and creator tracking
        let expiresAt = Date().addingTimeInterval(24 * 60 * 60)
        try await db.collection("familyCodes").document(code).setData([
            "familyID": familyRef.documentID,
            "createdAt": FieldValue.serverTimestamp(),
            "createdBy": ownerUserID,
            "expiresAt": Timestamp(date: expiresAt)
        ])

        return (familyRef.documentID, code)
    }

    func joinFamily(code: String, userID: String, displayName: String, role: AuthState.UserRole) async throws -> String {
        let codeRef = db.collection("familyCodes").document(code.uppercased())
        let codeDoc = try await codeRef.getDocument()
        guard let data = codeDoc.data(), let familyID = data["familyID"] as? String else {
            throw SyncError.invalidJoinCode
        }

        // Validate expiry
        if let expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue(),
           Date() > expiresAt {
            throw SyncError.joinCodeExpired
        }

        // Validate not already used
        if data["usedAt"] != nil {
            throw SyncError.joinCodeAlreadyUsed
        }

        // Mark code as used
        try await codeRef.updateData([
            "usedAt": FieldValue.serverTimestamp(),
            "usedBy": userID
        ])

        try await db.collection("users").document(userID).setData([
            "familyID": familyID,
            "role": role.rawValue,
            "displayName": displayName
        ])

        return familyID
    }

    func validateRole(userID: String) async throws -> AuthState? {
        let doc = try await db.collection("users").document(userID).getDocument()
        guard let data = doc.data(),
              let familyID = data["familyID"] as? String,
              let roleStr = data["role"] as? String,
              let role = AuthState.UserRole(rawValue: roleStr),
              let displayName = data["displayName"] as? String else {
            return nil
        }
        return AuthState(userID: userID, familyID: familyID, role: role, displayName: displayName)
    }

    // MARK: - Child Profiles

    func saveChildProfile(_ profile: ChildProfile, familyID: String) async throws {
        let data = try encoder.encode(profile)
        try await familyDoc(familyID).collection("children").document(profile.id.uuidString).setData(data)
    }

    func fetchChildProfiles(familyID: String) async throws -> [ChildProfile] {
        let snapshot = try await familyDoc(familyID).collection("children")
            .order(by: "createdAt").getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: ChildProfile.self) }
    }

    func observeChildProfiles(familyID: String) -> AsyncStream<[ChildProfile]> {
        collectionStream(familyDoc(familyID).collection("children").order(by: "createdAt"))
    }

    /// Deletes the child profile doc. Server-side `cleanupOnChildDelete` cascades
    /// alarms/sessions/tamperEvents. We only touch the child doc here — doing
    /// client-side batch cascades is racy with a child device still draining queue.
    func deleteChildProfile(_ childID: UUID, familyID: String) async throws {
        try await familyDoc(familyID).collection("children")
            .document(childID.uuidString).delete()
    }

    // MARK: - Alarm Schedules

    func saveAlarmSchedule(_ schedule: AlarmSchedule, familyID: String) async throws {
        let data = try encoder.encode(schedule)
        try await familyDoc(familyID).collection("alarms").document(schedule.id.uuidString).setData(data)
    }

    func deleteAlarmSchedule(_ scheduleID: UUID, familyID: String) async throws {
        try await familyDoc(familyID).collection("alarms").document(scheduleID.uuidString).delete()
    }

    func fetchAlarmSchedules(familyID: String, childID: UUID) async throws -> [AlarmSchedule] {
        let snapshot = try await familyDoc(familyID).collection("alarms")
            .whereField("childProfileID", isEqualTo: childID.uuidString)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: AlarmSchedule.self) }
    }

    func observeAlarmSchedules(familyID: String, childID: UUID) -> AsyncStream<[AlarmSchedule]> {
        let query = familyDoc(familyID).collection("alarms")
            .whereField("childProfileID", isEqualTo: childID.uuidString)
        return collectionStream(query)
    }

    // MARK: - Morning Sessions

    func saveSession(_ session: MorningSession, familyID: String) async throws {
        var data = try encoder.encode(session)
        // Overlay server timestamps for trustworthy audit trail
        data["lastUpdated"] = FieldValue.serverTimestamp()
        if session.verifiedAt != nil {
            data["serverVerifiedAt"] = FieldValue.serverTimestamp()
        }
        if session.parentActionAt != nil {
            data["serverParentActionAt"] = FieldValue.serverTimestamp()
        }
        try await familyDoc(familyID).collection("sessions").document(session.id.uuidString).setData(data)
    }

    func fetchSessions(familyID: String, childID: UUID, since: Date) async throws -> [MorningSession] {
        let snapshot = try await familyDoc(familyID).collection("sessions")
            .whereField("childProfileID", isEqualTo: childID.uuidString)
            .whereField("alarmFiredAt", isGreaterThan: Timestamp(date: since))
            .order(by: "alarmFiredAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: MorningSession.self) }
    }

    func observeActiveSessions(familyID: String, childID: UUID) -> AsyncStream<[MorningSession]> {
        let query = familyDoc(familyID).collection("sessions")
            .whereField("childProfileID", isEqualTo: childID.uuidString)
            .whereField("state", in: ["ringing", "snoozed", "escalating", "verifying", "pendingParentReview"])
        return collectionStream(query)
    }

    func observeSession(familyID: String, sessionID: UUID) -> AsyncStream<MorningSession?> {
        let ref = familyDoc(familyID).collection("sessions").document(sessionID.uuidString)
        return AsyncStream { continuation in
            let listener = ref.addSnapshotListener { snapshot, error in
                guard let snapshot, snapshot.exists else {
                    continuation.yield(nil)
                    return
                }
                let session = try? snapshot.data(as: MorningSession.self)
                continuation.yield(session)
            }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    // MARK: - Tamper Events

    func saveTamperEvent(_ event: TamperEvent, familyID: String) async throws {
        var data = try encoder.encode(event)
        data["serverTimestamp"] = FieldValue.serverTimestamp()
        try await familyDoc(familyID).collection("tamperEvents").document(event.id.uuidString).setData(data)
    }

    func fetchTamperEvents(familyID: String, childID: UUID, since: Date) async throws -> [TamperEvent] {
        let snapshot = try await familyDoc(familyID).collection("tamperEvents")
            .whereField("childProfileID", isEqualTo: childID.uuidString)
            .whereField("timestamp", isGreaterThan: Timestamp(date: since))
            .order(by: "timestamp", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: TamperEvent.self) }
    }

    func observeTamperEvents(familyID: String, childID: UUID) -> AsyncStream<[TamperEvent]> {
        let query = familyDoc(familyID).collection("tamperEvents")
            .whereField("childProfileID", isEqualTo: childID.uuidString)
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
        return collectionStream(query)
    }

    // MARK: - Atomic Operations

    func escalateSessionAndProfile(session: MorningSession, profile: ChildProfile, familyID: String) async throws {
        let batch = db.batch()

        let sessionRef = familyDoc(familyID).collection("sessions").document(session.id.uuidString)
        var sessionData = try encoder.encode(session)
        sessionData["lastUpdated"] = FieldValue.serverTimestamp()
        sessionData["serverParentActionAt"] = FieldValue.serverTimestamp()
        batch.setData(sessionData, forDocument: sessionRef)

        let profileRef = familyDoc(familyID).collection("children").document(profile.id.uuidString)
        let profileData = try encoder.encode(profile)
        batch.setData(profileData, forDocument: profileRef)

        try await batch.commit()
    }

    // MARK: - Heartbeat

    func updateHeartbeat(familyID: String, childID: UUID) async throws {
        try await familyDoc(familyID).collection("children").document(childID.uuidString).updateData([
            "lastHeartbeat": FieldValue.serverTimestamp()
        ])
    }

    // MARK: - Helpers

    private func familyDoc(_ familyID: String) -> DocumentReference {
        db.collection("families").document(familyID)
    }

    /// Classifies a Firestore error into a structured SyncWriteFailure.
    static func classifyError(_ error: Error) -> SyncWriteFailure {
        let nsError = error as NSError
        // FirebaseFirestore error codes: 7 = PERMISSION_DENIED, 16 = UNAUTHENTICATED
        // See: https://firebase.google.com/docs/reference/swift/firebasefirestore/api/reference/Enums/FirestoreErrorCode
        switch nsError.code {
        case 7: // PERMISSION_DENIED (rules rejected: version guard, field-level, state transition)
            return .rulesRejected(reason: nsError.localizedDescription)
        case 16: // UNAUTHENTICATED
            return .authExpired
        case 14, 4: // UNAVAILABLE, DEADLINE_EXCEEDED
            return .transientNetwork(underlying: error)
        default:
            return .unknown(underlying: error)
        }
    }

    private func generateJoinCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<10).map { _ in chars.randomElement() ?? Character("A") })
    }

    /// Generic helper: turns a Firestore query into an AsyncStream via snapshot listener.
    /// Logs errors but keeps the stream alive with empty results so UI doesn't hang.
    private func collectionStream<T: Decodable>(_ query: Query) -> AsyncStream<[T]> {
        AsyncStream { continuation in
            let listener = query.addSnapshotListener { snapshot, error in
                if let error {
                    DebugLog.log("[FirestoreSync] Listener error: \(error.localizedDescription)")
                    continuation.yield([])
                    return
                }
                guard let snapshot else {
                    continuation.yield([])
                    return
                }
                let items = snapshot.documents.compactMap { try? $0.data(as: T.self) }
                continuation.yield(items)
            }
            continuation.onTermination = { _ in listener.remove() }
        }
    }
}
