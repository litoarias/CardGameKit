import Foundation
import SwiftUI
import Testing
@testable import CardGameKit

@Suite("CardTableViewModel discard flow")
@MainActor
struct CardTableViewModelDiscardTests {

    @Test("human discard is prioritized over bot discards")
    func humanDiscardIsPrioritized() async {
        let recorder = DiscardBotRecorder()
        let vm = CardTableViewModel<TestDiscardEngine>(
            engineFactory: {
                TestDiscardEngine(
                    phase: .discard,
                    turnSeat: .top,
                    pendingDiscardSeats: [.bottom, .top]
                )
            },
            botDecider: { seat, _ in
                recorder.calledSeats.append(seat)
                return .discard([])
            },
            turnTimerDuration: 999
        )

        await vm.driveLoop()

        #expect(recorder.calledSeats.isEmpty)
        #expect(vm.humanTimerActive)
        #expect(vm.engine.pendingDiscardSeats == [.bottom, .top])
    }
}

@MainActor
private final class DiscardBotRecorder {
    var calledSeats: [Seat] = []
}

@MainActor
private struct TestDiscardEngine: CardGameEngine {
    var phase: TestPhase
    var turnSeat: Seat
    var manoSeat: Seat = .bottom
    var scores: [TeamSide: Int] = [.home: 0, .away: 0]
    var roundResults: [TestRoundResult] = []
    var pendingDiscardSeats: Set<Seat>

    static let winningScore = 40

    static func teamName(for side: TeamSide) -> String {
        side == .home ? "Home" : "Away"
    }

    static let decisionLabels: (agree: String, disagree: String) = ("Yes", "No")

    func player(at seat: Seat) -> TestPlayer {
        TestPlayer(name: "P\(seat.rawValue)", side: seat == .bottom || seat == .top ? .home : .away)
    }

    func legalActions() -> [TestAction] { [] }

    mutating func executeDecision(seat: Seat, agrees: Bool) {}

    mutating func executeDiscard(seat: Seat, indices: Set<Int>) {
        pendingDiscardSeats.remove(seat)
    }

    mutating func executeAction(_ action: TestAction) {}

    mutating func newHand() {}
}

@MainActor
private enum TestPhase: Equatable, CardGamePhase {
    case discard

    var kind: PhaseKind { .discard }
    var displayName: String { "DISCARD" }
    var gameOverWinner: TeamSide? { nil }
}

@MainActor
private enum TestAction: Hashable, CardGameAction {
    case none

    var displayText: String { "None" }
    var buttonColor: Color { .gray }
    var particleBurst: Int { 0 }
}

@MainActor
private struct TestRoundResult: CardGameRoundResult {
    let id = "discard"
    let sectionName = "discard"
    let winner: TeamSide = .home
    let mainPoints = 0
    let bonusPoints = 0
    let rejectedPoints = 0
    let totalPoints = 0
}

@MainActor
private struct TestPlayer: CardGamePlayer {
    let id = UUID()
    let name: String
    let side: TeamSide
    let cards: [Card] = []
    let avatarSystemImage = "person"
    let isHuman = false
}
