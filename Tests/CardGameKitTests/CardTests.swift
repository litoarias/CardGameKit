import Foundation
import Testing
@testable import CardGameKit

@Suite("Card")
struct CardTests {
    @Test("Asset name format is rank_suit")
    func assetNameFormat() {
        let card = Card(rank: .sota, suit: .copas)
        #expect(card.assetName == "sota_copas")
    }

    @Test("ID is stable and unique across 40 cards")
    func uniqueIDs() {
        let deck = Deck.spanish40()
        let ids = deck.cards.map(\.id)
        let unique = Set(ids)
        #expect(ids.count == 40)
        #expect(unique.count == 40)
    }

    @Test("Round-trips through Codable")
    func codable() throws {
        let card = Card(rank: .rey, suit: .espadas)
        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(Card.self, from: data)
        #expect(decoded == card)
    }

    @Test("All 40 cards have non-empty asset names")
    func allAssetNamesNonEmpty() {
        let deck = Deck.spanish40()
        for card in deck.cards {
            #expect(!card.assetName.isEmpty)
            #expect(card.assetName.contains("_"))
        }
    }
}
