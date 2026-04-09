import SwiftUI

/// An action a player can execute, with all display metadata the UI needs.
public protocol CardGameAction: Sendable, Equatable, Hashable {
    /// Label shown on the action button.
    var displayText: String { get }

    /// Color for the action button.
    var buttonColor: Color { get }

    /// Number of particles to spawn when this action is played (0 = none).
    var particleBurst: Int { get }
}
