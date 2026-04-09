import Foundation

/// The move a bot returns for a given situation.
public enum BotMove<Action: CardGameAction>: Sendable {
    /// Yes/no decision phase.
    case decision(Bool)
    /// Select cards to discard (indices into the hand).
    case discard(Set<Int>)
    /// Execute a game action (bet, pass, etc.).
    case action(Action)
}

/// A bot that can decide moves for any conforming engine.
public protocol CardGameBot: Sendable {
    associatedtype Engine: CardGameEngine
    func decide(engine: Engine, seat: Seat) async -> BotMove<Engine.Action>
}
