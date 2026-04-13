import Foundation
import CloudKit

/// Manages all CloudKit operations for syncing alarm schedules, child profiles,
/// and morning sessions between parent and child devices.
///
/// Uses a shared CloudKit container so both parent-mode and child-mode instances
/// of the same app can read/write the same records. The parent writes alarm configs;
/// the child writes session state and heartbeats.
actor CloudSyncService {
    static let shared = CloudSyncService()

    // TODO: Replace with your actual CloudKit container identifier from the Apple Developer portal.
    private let containerID = "iCloud.com.momclock.MomAlarmClock"
    private lazy var container = CKContainer(identifier: containerID)
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private var sharedDB: CKDatabase { container.sharedCloudDatabase }

    // MARK: - Record Types

    enum RecordType {
        static let childProfile = "ChildProfile"
        static let alarmSchedule = "AlarmSchedule"
        static let morningSession = "MorningSession"
        static let tamperEvent = "TamperEvent"
    }

    // MARK: - Save

    /// Saves a child profile to CloudKit. Creates a new record or updates existing.
    func save(childProfile: ChildProfile) async throws -> CKRecord {
        let record = try encode(childProfile, recordType: RecordType.childProfile)
        return try await privateDB.save(record)
    }

    /// Saves an alarm schedule to CloudKit.
    func save(alarmSchedule: AlarmSchedule) async throws -> CKRecord {
        let record = try encode(alarmSchedule, recordType: RecordType.alarmSchedule)
        return try await privateDB.save(record)
    }

    /// Saves a morning session update to CloudKit.
    func save(morningSession: MorningSession) async throws -> CKRecord {
        let record = try encode(morningSession, recordType: RecordType.morningSession)
        return try await privateDB.save(record)
    }

    /// Reports a tamper event to CloudKit so the parent sees it in near real time.
    func report(tamperEvent: TamperEvent) async throws -> CKRecord {
        let record = try encode(tamperEvent, recordType: RecordType.tamperEvent)
        return try await privateDB.save(record)
    }

    // MARK: - Fetch

    /// Fetches all child profiles for the current iCloud account.
    func fetchChildProfiles() async throws -> [ChildProfile] {
        let query = CKQuery(
            recordType: RecordType.childProfile,
            predicate: NSPredicate(value: true)
        )
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        let (results, _) = try await privateDB.records(matching: query)
        return results.compactMap { _, result in
            guard let record = try? result.get() else { return nil }
            return try? decode(ChildProfile.self, from: record)
        }
    }

    /// Fetches alarm schedules for a specific child.
    func fetchAlarmSchedules(forChild childID: UUID) async throws -> [AlarmSchedule] {
        let predicate = NSPredicate(format: "childProfileID == %@", childID.uuidString)
        let query = CKQuery(recordType: RecordType.alarmSchedule, predicate: predicate)
        let (results, _) = try await privateDB.records(matching: query)
        return results.compactMap { _, result in
            guard let record = try? result.get() else { return nil }
            return try? decode(AlarmSchedule.self, from: record)
        }
    }

    /// Fetches morning sessions for a child within a date range.
    func fetchMorningSessions(
        forChild childID: UUID,
        from startDate: Date,
        to endDate: Date = .now
    ) async throws -> [MorningSession] {
        let predicate = NSPredicate(
            format: "childProfileID == %@ AND alarmFiredAt >= %@ AND alarmFiredAt <= %@",
            childID.uuidString,
            startDate as NSDate,
            endDate as NSDate
        )
        let query = CKQuery(recordType: RecordType.morningSession, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "alarmFiredAt", ascending: false)]
        let (results, _) = try await privateDB.records(matching: query)
        return results.compactMap { _, result in
            guard let record = try? result.get() else { return nil }
            return try? decode(MorningSession.self, from: record)
        }
    }

    // MARK: - Subscriptions

    /// Subscribes to changes in alarm schedules (child device listens for parent updates).
    func subscribeToAlarmChanges(forChild childID: UUID) async throws {
        let predicate = NSPredicate(format: "childProfileID == %@", childID.uuidString)
        let subscription = CKQuerySubscription(
            recordType: RecordType.alarmSchedule,
            predicate: predicate,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true // Silent push to trigger background fetch
        subscription.notificationInfo = info

        try await privateDB.save(subscription)
    }

    /// Subscribes to morning session updates (parent device listens for child status).
    func subscribeToSessionChanges(forChild childID: UUID) async throws {
        let predicate = NSPredicate(format: "childProfileID == %@", childID.uuidString)
        let subscription = CKQuerySubscription(
            recordType: RecordType.morningSession,
            predicate: predicate,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        let info = CKSubscription.NotificationInfo()
        info.alertBody = "Morning session update"
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info

        try await privateDB.save(subscription)
    }

    // MARK: - Encoding / Decoding

    private func encode<T: Codable>(_ value: T, recordType: String) throws -> CKRecord {
        let data = try JSONEncoder().encode(value)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CloudSyncError.encodingFailed
        }
        let recordID = CKRecord.ID(recordName: (dict["id"] as? String) ?? UUID().uuidString)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        for (key, value) in dict {
            if let stringValue = value as? String {
                record[key] = stringValue as CKRecordValue
            } else if let numberValue = value as? NSNumber {
                record[key] = numberValue as CKRecordValue
            } else {
                // Store complex nested values as JSON data
                let nestedData = try JSONSerialization.data(withJSONObject: value)
                record[key] = String(data: nestedData, encoding: .utf8) as? CKRecordValue
            }
        }
        return record
    }

    private func decode<T: Codable>(_ type: T.Type, from record: CKRecord) throws -> T {
        var dict: [String: Any] = [:]
        for key in record.allKeys() {
            dict[key] = record[key]
        }
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Errors

enum CloudSyncError: LocalizedError {
    case encodingFailed
    case decodingFailed
    case recordNotFound
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .encodingFailed:     "Failed to encode data for CloudKit."
        case .decodingFailed:     "Failed to decode data from CloudKit."
        case .recordNotFound:     "CloudKit record not found."
        case .notAuthenticated:   "Not signed in to iCloud."
        }
    }
}
