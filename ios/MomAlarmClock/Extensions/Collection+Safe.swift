import Foundation

extension Collection {
    /// Safe subscript that returns nil instead of crashing on out-of-bounds.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
