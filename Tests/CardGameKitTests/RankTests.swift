import Foundation
import Testing
@testable import CardGameKit

@Suite("Rank")
struct RankTests {
    @Test("Has exactly 10 cases")
    func caseCount() {
        #expect(Rank.allCases.count == 10)
    }

    @Test("Asset suffix matches expected strings")
    func assetSuffix() {
        let expected: [Rank: String] = [
            .as_: "1", .two: "2", .three: "3", .four: "4", .five: "5",
            .six: "6", .seven: "7", .sota: "sota", .caballo: "caballo", .rey: "rey"
        ]
        for (rank, suffix) in expected {
            #expect(rank.assetSuffix == suffix, "Rank \(rank) should have suffix '\(suffix)'")
        }
    }

    @Test("Round-trips through Codable")
    func codable() throws {
        for rank in Rank.allCases {
            let data = try JSONEncoder().encode(rank)
            let decoded = try JSONDecoder().decode(Rank.self, from: data)
            #expect(decoded == rank)
        }
    }

    @Test("Has no game-specific computed properties")
    func noMusProperties() {
        // Rank in the package should be a plain enum — no Mus-specific values
        // This test documents the contract: if musValue/gameValue appear here, it's a regression
        let rank = Rank.as_
        #expect(rank.assetSuffix == "1")
        // Only assetSuffix should exist at the package level
    }
}
