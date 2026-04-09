import Foundation

/// A single section of the round summary (e.g. a lance in Mus, a round in Truco).
public protocol CardGameRoundResult: Sendable, Identifiable where ID == String {
    /// Name displayed in the summary row (e.g. "Grande", "Chica").
    var sectionName: String { get }

    var winner: TeamSide { get }

    /// Points from accepted bets/envites.
    var mainPoints: Int { get }

    /// Bonus points (pares, juego, etc.).
    var bonusPoints: Int { get }

    /// Points from a rejected bet (no querido).
    var rejectedPoints: Int { get }

    var totalPoints: Int { get }
}
