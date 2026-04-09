import Foundation

/// A player as visible to the visual layer.
public protocol CardGamePlayer: Identifiable, Sendable where ID == UUID {
    var name: String { get }
    var side: TeamSide { get }
    /// Cards currently in hand.
    var cards: [Card] { get }
    var avatarSystemImage: String { get }
    var isHuman: Bool { get }
}
