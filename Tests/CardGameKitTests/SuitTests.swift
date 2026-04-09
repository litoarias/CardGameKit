import Foundation
import Testing
@testable import CardGameKit

@Suite("Suit")
struct SuitTests {
    @Test("Has exactly 4 cases")
    func caseCount() {
        #expect(Suit.allCases.count == 4)
    }

    @Test("Raw values match Spanish deck names")
    func rawValues() {
        #expect(Suit.oros.rawValue == "oros")
        #expect(Suit.copas.rawValue == "copas")
        #expect(Suit.espadas.rawValue == "espadas")
        #expect(Suit.bastos.rawValue == "bastos")
    }

    @Test("Round-trips through Codable")
    func codable() throws {
        for suit in Suit.allCases {
            let data = try JSONEncoder().encode(suit)
            let decoded = try JSONDecoder().decode(Suit.self, from: data)
            #expect(decoded == suit)
        }
    }
}
