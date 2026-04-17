import Foundation

/// A guardian-configurable reward that children can redeem with points.
struct Reward: Codable, Identifiable, Sendable, Equatable {
    var id: UUID = UUID()
    var name: String
    var points: Int
    var icon: String
    var description: String?
    var createdAt: Date = Date()

    /// Default reward set used when a family is first created or the list is empty.
    /// Guardians can edit, remove, or replace these.
    static let defaults: [Reward] = [
        Reward(name: "Extra 30 min Screen Time", points: 50, icon: "iphone"),
        Reward(name: "Pick Dinner Tonight", points: 100, icon: "fork.knife"),
        Reward(name: "Stay Up 30 min Later", points: 150, icon: "moon.stars"),
        Reward(name: "Movie Night Pick", points: 200, icon: "film"),
        Reward(name: "Weekend Outing Choice", points: 500, icon: "car"),
    ]

    /// Available SF Symbol icons guardians can choose from.
    static let availableIcons: [(name: String, label: String)] = [
        ("iphone", "Screen Time"),
        ("fork.knife", "Food"),
        ("moon.stars", "Bedtime"),
        ("film", "Movie"),
        ("car", "Outing"),
        ("gift.fill", "Gift"),
        ("star.fill", "Special"),
        ("gamecontroller.fill", "Games"),
        ("tv.fill", "TV"),
        ("ice.cream.fill", "Treat"),
        ("hand.raised.fill", "Choice"),
        ("sparkles", "Surprise"),
    ]
}
