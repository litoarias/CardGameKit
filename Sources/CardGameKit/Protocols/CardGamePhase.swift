import Foundation

/// A game phase as seen by the visual layer.
public protocol CardGamePhase: Sendable, Equatable {
    /// What kind of UI interaction this phase requires.
    var kind: PhaseKind { get }

    /// Short label shown in the scoreboard / phase indicator.
    var displayName: String { get }

    /// Non-nil only when kind == .gameOver.
    var gameOverWinner: TeamSide? { get }
}
