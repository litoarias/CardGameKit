import Foundation

/// Generic side (team) in a card game.
public enum TeamSide: Int, Sendable, CaseIterable, Hashable, Codable {
    case home = 1
    case away = 2
}

/// Category of interaction the current phase requires from the UI.
public enum PhaseKind: Sendable, Equatable {
    /// Yes/no decision (e.g. Mus/Corto, accept Truco).
    case decision
    /// Select cards to discard.
    case discard
    /// Choose an action from a list.
    case bet
    /// Hand finished — show round summary.
    case handEnd
    /// Game finished.
    case gameOver
}

/// Protocol for a card game engine that the visual layer can drive generically.
public protocol CardGameEngine: Sendable {
    associatedtype Phase: CardGamePhase
    associatedtype Action: CardGameAction
    associatedtype Result: CardGameRoundResult
    associatedtype Player: CardGamePlayer

    // MARK: - State

    var phase: Phase { get }
    var turnSeat: Seat { get }
    var manoSeat: Seat { get }
    var scores: [TeamSide: Int] { get }
    var roundResults: [Result] { get }
    var pendingDiscardSeats: Set<Seat> { get }

    // MARK: - Queries

    func player(at seat: Seat) -> Player
    func legalActions() -> [Action]

    // MARK: - Game config

    /// Points needed to win the game.
    static var winningScore: Int { get }

    /// Display name for each team.
    static func teamName(for side: TeamSide) -> String

    /// Labels shown on the two decision buttons (agree, disagree).
    static var decisionLabels: (agree: String, disagree: String) { get }

    // MARK: - Mutations

    mutating func executeDecision(seat: Seat, agrees: Bool)
    mutating func executeDiscard(seat: Seat, indices: Set<Int>)
    mutating func executeAction(_ action: Action)
    mutating func newHand()
}
