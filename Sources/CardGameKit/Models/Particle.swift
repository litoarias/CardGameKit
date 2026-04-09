import Foundation

/// A persistent particle on the table surface (e.g. a scoring token).
public struct Particle: Identifiable, Sendable, Equatable {
    public let id: UUID
    public var x: Double            // 0..1 normalized width
    public var y: Double            // 0..1 normalized height
    public var rotation: Double
    public var size: Double
    public var bornAt: Date
    /// Per-particle hue shift for natural color variation (−0.04…+0.04).
    public var hueShift: Double
    /// Delay in seconds before entrance animation starts (for staggered bursts).
    public var spawnDelay: Double

    public init(
        id: UUID = UUID(),
        x: Double,
        y: Double,
        rotation: Double,
        size: Double,
        bornAt: Date = Date(),
        hueShift: Double,
        spawnDelay: Double
    ) {
        self.id = id
        self.x = x
        self.y = y
        self.rotation = rotation
        self.size = size
        self.bornAt = bornAt
        self.hueShift = hueShift
        self.spawnDelay = spawnDelay
    }

    /// Creates a randomly positioned particle restricted to the center pot zone.
    public static func random(delay: Double = 0) -> Particle {
        Particle(
            x: Double.random(in: 0.30...0.70),
            y: Double.random(in: 0.38...0.55),
            rotation: Double.random(in: 0...(2 * .pi)),
            size: Double.random(in: 16...24),
            hueShift: Double.random(in: -0.04...0.04),
            spawnDelay: delay
        )
    }
}
