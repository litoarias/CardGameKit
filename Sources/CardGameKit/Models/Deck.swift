import Foundation

/// A Spanish 40-card deck. Value type with pure operations.
public struct Deck: Sendable {
    public private(set) var cards: [Card]

    public init(cards: [Card]) { self.cards = cards }

    /// Creates a full 40-card Spanish deck (no 8 or 9).
    public static func spanish40() -> Deck {
        var all: [Card] = []
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                all.append(Card(rank: rank, suit: suit))
            }
        }
        return Deck(cards: all)
    }

    public mutating func shuffle(using generator: inout some RandomNumberGenerator) {
        cards.shuffle(using: &generator)
    }

    public mutating func draw() -> Card? {
        cards.popLast()
    }

    public mutating func draw(_ n: Int) -> [Card] {
        var out: [Card] = []
        for _ in 0..<n {
            if let c = draw() { out.append(c) }
        }
        return out
    }

    public var count: Int { cards.count }

    /// Returns cards to the bottom of the deck (for recycling discards).
    public mutating func recycleAtBottom(_ cs: [Card]) {
        cards.insert(contentsOf: cs, at: 0)
    }
}
