import Foundation

/// Card fan orientation based on seat position at the table.
public enum FanOrientation: Sendable {
    case down    // partner above: cards point down
    case right   // left bot: cards point right
    case left    // right bot: cards point left
    case up      // human: cards point up (normal)
}
