import Foundation

/// A player as visible to the visual layer.
@MainActor
public protocol CardGamePlayer: Identifiable where ID == UUID {
    var name: String { get }
    var side: TeamSide { get }
    /// Cards currently in hand.
    var cards: [Card] { get }
    var avatarSystemImage: String { get }
    var isHuman: Bool { get }
}
