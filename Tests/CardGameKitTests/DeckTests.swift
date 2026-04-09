import Testing
@testable import CardGameKit

@Suite("Deck")
struct DeckTests {
    @Test("spanish40 returns exactly 40 unique cards")
    func spanish40Count() {
        let deck = Deck.spanish40()
        #expect(deck.count == 40)
        let unique = Set(deck.cards.map(\.id))
        #expect(unique.count == 40)
    }

    @Test("Contains all suits × all ranks")
    func allCombinations() {
        let deck = Deck.spanish40()
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                let exists = deck.cards.contains { $0.suit == suit && $0.rank == rank }
                #expect(exists, "Missing \(rank)_\(suit)")
            }
        }
    }

    @Test("draw reduces count by 1")
    func drawReducesCount() {
        var deck = Deck.spanish40()
        let card = deck.draw()
        #expect(card != nil)
        #expect(deck.count == 39)
    }

    @Test("draw(n) returns exactly n cards")
    func drawN() {
        var deck = Deck.spanish40()
        let cards = deck.draw(4)
        #expect(cards.count == 4)
        #expect(deck.count == 36)
    }

    @Test("draw from empty deck returns nil")
    func drawEmpty() {
        var deck = Deck(cards: [])
        #expect(deck.draw() == nil)
    }

    @Test("recycleAtBottom restores cards to bottom")
    func recycleAtBottom() {
        var deck = Deck.spanish40()
        let drawn = deck.draw(4)
        #expect(deck.count == 36)
        deck.recycleAtBottom(drawn)
        #expect(deck.count == 40)
    }

    @Test("shuffle changes order (seeded RNG)")
    func shuffleChangesOrder() {
        var deck1 = Deck.spanish40()
        let deck2 = Deck.spanish40()
        var rng = SeededRNG(seed: 42)
        deck1.shuffle(using: &rng)
        // Shuffled deck should differ from unshuffled (with overwhelming probability)
        #expect(deck1.cards != deck2.cards)
    }
}

/// Simple seeded RNG for deterministic tests.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
