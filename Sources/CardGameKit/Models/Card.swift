import Foundation

/// A card from the Spanish 40-card deck.
public struct Card: Hashable, Sendable, Codable, Identifiable {
    public let rank: Rank
    public let suit: Suit

    public init(rank: Rank, suit: Suit) {
        self.rank = rank
        self.suit = suit
    }

    /// Stable string identifier, e.g. "1_oros", "sota_copas".
    public var id: String { "\(rank.rawValue)_\(suit.rawValue)" }

    /// Asset name matching images in CardGameKit's resource bundle.
    public var assetName: String { "\(rank.assetSuffix)_\(suit.rawValue)" }
}
