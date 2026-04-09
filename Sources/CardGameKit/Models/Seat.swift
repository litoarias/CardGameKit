import Foundation

/// Player seat position at the table.
/// 0 = human (bottom), 1 = left bot, 2 = partner (top), 3 = right bot.
/// Team assignments are game-specific and defined by each app via extension.
public enum Seat: Int, CaseIterable, Sendable, Hashable {
    case bottom = 0, left = 1, top = 2, right = 3

    /// Next seat in turn order (clockwise from mano).
    public var next: Seat { Seat(rawValue: (rawValue + 1) % 4)! }
}
