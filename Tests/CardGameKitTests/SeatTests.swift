import Testing
@testable import CardGameKit

@Suite("Seat")
struct SeatTests {
    @Test("Has exactly 4 cases")
    func caseCount() {
        #expect(Seat.allCases.count == 4)
    }

    @Test("next cycles through all 4 seats")
    func nextCycles() {
        var seat = Seat.bottom
        let expected: [Seat] = [.left, .top, .right, .bottom]
        for exp in expected {
            seat = seat.next
            #expect(seat == exp)
        }
    }

    @Test("Raw values are 0-3")
    func rawValues() {
        #expect(Seat.bottom.rawValue == 0)
        #expect(Seat.left.rawValue == 1)
        #expect(Seat.top.rawValue == 2)
        #expect(Seat.right.rawValue == 3)
    }
}
