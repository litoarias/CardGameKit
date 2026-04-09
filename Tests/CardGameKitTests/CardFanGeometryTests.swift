import Testing
@testable import CardGameKit

@Suite("CardFanGeometry")
struct CardFanGeometryTests {
    private let geo = CardFanGeometry(spreadAngle: 20, overlapRatio: 0.40)

    @Test("Single card: angle is 0")
    func singleCardAngle() {
        #expect(geo.angle(at: 0, of: 1) == 0)
    }

    @Test("Single card: xOffset is 0")
    func singleCardXOffset() {
        #expect(geo.xOffset(at: 0, of: 1, cardWidth: 100) == 0)
    }

    @Test("Two cards: angles are symmetric around 0")
    func twoCardsSymmetric() {
        let a0 = geo.angle(at: 0, of: 2)
        let a1 = geo.angle(at: 1, of: 2)
        #expect(a0 == -10)
        #expect(a1 == 10)
        #expect(a0 == -a1)
    }

    @Test("Four cards: angles evenly distributed across spread")
    func fourCardsDistributed() {
        let angles = (0..<4).map { geo.angle(at: $0, of: 4) }
        #expect(angles.first! == -10)
        #expect(angles.last! == 10)
        // Step between each angle should be equal
        let steps = zip(angles, angles.dropFirst()).map { $1 - $0 }
        for step in steps {
            #expect(abs(step - steps[0]) < 0.001)
        }
    }

    @Test("Center card has zero xOffset for odd counts")
    func centerCardZeroOffset() {
        let xOff = geo.xOffset(at: 2, of: 5, cardWidth: 100)
        #expect(abs(xOff) < 0.001)
    }

    @Test("Custom spreadAngle is respected")
    func customSpread() {
        let custom = CardFanGeometry(spreadAngle: 30)
        let a0 = custom.angle(at: 0, of: 2)
        let a1 = custom.angle(at: 1, of: 2)
        #expect(a0 == -15)
        #expect(a1 == 15)
    }

    @Test("yOffset is non-positive (cards lift up)")
    func yOffsetNonPositive() {
        for idx in 0..<4 {
            #expect(geo.yOffset(at: idx, of: 4) <= 0)
        }
    }
}
