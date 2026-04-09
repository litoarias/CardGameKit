import CoreGraphics

/// Pure geometry calculations for a card fan layout.
/// Testable without SwiftUI; used by `CardFanView` and `PlayerSeatView`.
public struct CardFanGeometry: Sendable {
    /// Total spread in degrees across all cards.
    public let spreadAngle: Double
    /// Horizontal overlap as a fraction of card width.
    public let overlapRatio: Double

    public init(spreadAngle: Double = 20, overlapRatio: Double = 0.40) {
        self.spreadAngle = spreadAngle
        self.overlapRatio = overlapRatio
    }

    /// Rotation angle in degrees for card at `index` in a fan of `count` cards.
    public func angle(at index: Int, of count: Int) -> Double {
        guard count > 1 else { return 0 }
        let step = spreadAngle / Double(count - 1)
        return -spreadAngle / 2 + step * Double(index)
    }

    /// Horizontal offset for card at `index`, given `cardWidth`.
    public func xOffset(at index: Int, of count: Int, cardWidth: CGFloat) -> CGFloat {
        guard count > 1 else { return 0 }
        let overlap = cardWidth * overlapRatio
        let center = CGFloat(count - 1) / 2
        return (CGFloat(index) - center) * overlap
    }

    /// Vertical lift based on angle (cards at edges lift slightly).
    public func yOffset(at index: Int, of count: Int) -> CGFloat {
        -abs(CGFloat(angle(at: index, of: count))) * 0.25
    }
}
