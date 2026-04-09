import Foundation
import Observation
import SwiftUI

/// Generic view model that drives any `CardGameEngine` from the visual layer.
/// Handles deal animation, bot timing, human timer, particles, and round summary.
@Observable
@MainActor
public final class CardTableViewModel<Engine: CardGameEngine> {

    // MARK: - Engine + dependencies

    public private(set) var engine: Engine
    private let botDecider: @Sendable (Seat, Engine) async -> BotMove<Engine.Action>
    private let engineFactory: @Sendable () -> Engine
    /// Optional provider for seat speech bubbles (game-specific announcements).
    public let bubbleProvider: (@Sendable (Seat, Engine) -> String?)?

    // MARK: - Bot/thinking state

    public private(set) var isThinking: Bool = false
    public private(set) var thinkingSeat: Seat? = nil
    public private(set) var lastBotAction: String? = nil
    public private(set) var animationTrigger: Int = 0

    // MARK: - Deal animation state

    public private(set) var dealAnimationID: Int = 1
    public private(set) var isDealing: Bool = false
    public private(set) var dealRevealedCount: Int = 0
    public private(set) var deckSettled: Bool = false
    public private(set) var deckRotation: Double = 0
    public private(set) var deckLayerRotations: [Double] = Array(repeating: 0, count: 5)

    // MARK: - Round summary

    public private(set) var showRoundSummary: Bool = false
    public private(set) var summaryResults: [Engine.Result] = []
    public private(set) var summaryScoreHome: Int = 0
    public private(set) var summaryScoreAway: Int = 0
    private var summaryContinuation: CheckedContinuation<Void, Never>?

    // MARK: - Human timer

    public private(set) var humanTimerActive: Bool = false
    public let turnTimerDuration: TimeInterval = 10
    public let botThinkDuration: TimeInterval = 0.7
    private var turnTimerTask: Task<Void, Never>?

    // MARK: - Human interaction state

    public var selectedDiscardIndices: Set<Int> = []
    public var humanName: String

    // MARK: - Particles

    public private(set) var particles: [Particle] = []

    // MARK: - Computed helpers

    public var isHumanTurn: Bool { engine.turnSeat == .bottom }

    // MARK: - Init

    public init(
        engineFactory: @escaping @Sendable () -> Engine,
        botDecider: @escaping @Sendable (Seat, Engine) async -> BotMove<Engine.Action>,
        humanName: String = "Jugador",
        bubbleProvider: (@Sendable (Seat, Engine) -> String?)? = nil
    ) {
        self.engineFactory = engineFactory
        self.engine = engineFactory()
        self.botDecider = botDecider
        self.humanName = humanName
        self.bubbleProvider = bubbleProvider
    }

    // MARK: - Human actions

    public func humanDecision(_ agrees: Bool) {
        guard !isDealing else { return }
        stopHumanTimer()
        engine.executeDecision(seat: .bottom, agrees: agrees)
        animationTrigger += 1
        Task { await driveLoop() }
    }

    public func humanConfirmDiscard() {
        guard !isDealing else { return }
        stopHumanTimer()
        guard !selectedDiscardIndices.isEmpty else { return }
        engine.executeDiscard(seat: .bottom, indices: selectedDiscardIndices)
        selectedDiscardIndices = []
        Task { await driveLoop() }
    }

    public func humanExecute(_ action: Engine.Action) {
        guard !isDealing else { return }
        stopHumanTimer()
        engine.executeAction(action)
        animationTrigger += 1
        spawnParticleBurst(count: action.particleBurst)
        Task { await driveLoop() }
    }

    public func continuarDesdeSummary() {
        showRoundSummary = false
        summaryContinuation?.resume()
        summaryContinuation = nil
    }

    public func newGame() {
        stopHumanTimer()
        engine = engineFactory()
        particles = []
        lastBotAction = nil
        animationTrigger = 0
        dealAnimationID += 1
        dealRevealedCount = 0
        isDealing = true
        selectedDiscardIndices = []
        Task { @MainActor in
            await animateDeal()
            await driveLoop()
        }
    }

    // MARK: - Game loop

    /// Drives the game forward by processing bot turns and phase transitions.
    /// Exits when it's the human's turn or the game is over.
    public func driveLoop() async {
        loop: while true {
            switch engine.phase.kind {
            case .gameOver:
                break loop

            case .handEnd:
                spawnParticlesForResults()
                summaryResults = engine.roundResults
                summaryScoreHome = engine.scores[.home] ?? 0
                summaryScoreAway = engine.scores[.away] ?? 0
                showRoundSummary = true
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    self.summaryContinuation = cont
                }
                clearParticles()
                startNewHand()
                return

            case .discard:
                await processBotDiscards()
                if engine.phase.kind == .discard {
                    startHumanTimer()
                    break loop
                }
                continue loop

            case .decision, .bet:
                if isHumanTurn {
                    startHumanTimer()
                    break loop
                }
                isThinking = true
                thinkingSeat = engine.turnSeat
                try? await Task.sleep(for: .milliseconds(700))
                await processBotTurn()
                thinkingSeat = nil
                isThinking = false
                animationTrigger += 1
            }
        }
    }

    // MARK: - Bot coordination

    private func processBotDiscards() async {
        let botSeats: [Seat] = [.right, .top, .left]
        for seat in botSeats {
            guard engine.phase.kind == .discard else { return }
            guard engine.pendingDiscardSeats.contains(seat) else { continue }
            isThinking = true
            thinkingSeat = seat
            try? await Task.sleep(for: .milliseconds(500))
            let move = await botDecider(seat, engine)
            let player = engine.player(at: seat)
            if case .discard(let indices) = move {
                lastBotAction = "\(player.name) descarta \(indices.count)"
                engine.executeDiscard(seat: seat, indices: indices)
                animationTrigger += 1
            }
            thinkingSeat = nil
            isThinking = false
        }
    }

    private func processBotTurn() async {
        let seat = engine.turnSeat
        let move = await botDecider(seat, engine)
        let player = engine.player(at: seat)
        switch move {
        case .decision(let agrees):
            lastBotAction = "\(player.name): \(agrees ? "Sí" : "No")"
            engine.executeDecision(seat: seat, agrees: agrees)
        case .discard(let indices):
            lastBotAction = "\(player.name) descarta \(indices.count)"
            engine.executeDiscard(seat: seat, indices: indices)
            dealAnimationID += 1
        case .action(let action):
            lastBotAction = "\(player.name): \(action.displayText)"
            engine.executeAction(action)
            spawnParticleBurst(count: action.particleBurst)
        }
    }

    // MARK: - Human timer

    public func startHumanTimer() {
        stopHumanTimer()
        humanTimerActive = true
        turnTimerTask = Task {
            try? await Task.sleep(for: .seconds(turnTimerDuration))
            if Task.isCancelled { return }
            humanTimerActive = false
            playDefaultAction()
        }
    }

    public func stopHumanTimer() {
        turnTimerTask?.cancel()
        turnTimerTask = nil
        humanTimerActive = false
    }

    private func playDefaultAction() {
        switch engine.phase.kind {
        case .decision:
            humanDecision(true)
        case .discard:
            if selectedDiscardIndices.isEmpty { selectedDiscardIndices = [0] }
            humanConfirmDiscard()
        case .bet:
            let actions = engine.legalActions()
            if let first = actions.first { humanExecute(first) }
        default:
            break
        }
    }

    // MARK: - Deal animation

    public func animateDeal() async {
        dealRevealedCount = 0
        isDealing = true
        deckSettled = false
        try? await Task.sleep(for: .milliseconds(350))
        for i in 1...16 {
            let pause: Int = (i > 1 && (i - 1) % 4 == 0) ? 140 : 50
            try? await Task.sleep(for: .milliseconds(pause))
            withAnimation(.spring(duration: 0.5, bounce: 0.28)) {
                dealRevealedCount = i
            }
        }
        try? await Task.sleep(for: .milliseconds(200))
        isDealing = false
        deckRotation = Double.random(in: -60...60)
        deckLayerRotations = (0..<5).map { _ in Double.random(in: -6...6) }
        withAnimation(.spring(duration: 0.7, bounce: 0.2)) {
            deckSettled = true
        }
    }

    /// Deal order for a card: 0..15, round-robin across seats.
    public func dealOrder(for seat: Seat, cardIndex: Int) -> Int {
        let seatOffset: Int = switch seat {
        case .bottom: 0
        case .right:  1
        case .top:    2
        case .left:   3
        }
        return cardIndex * 4 + seatOffset
    }

    // MARK: - New hand

    private func startNewHand() {
        stopHumanTimer()
        engine.newHand()
        dealAnimationID += 1
        dealRevealedCount = 0
        isDealing = true
        Task { @MainActor in
            await animateDeal()
            await driveLoop()
        }
    }

    // MARK: - Particles

    private func spawnParticleBurst(count: Int) {
        guard count > 0 else { return }
        for i in 0..<count {
            let delay = Double(i) * 0.06
            particles.append(Particle.random(delay: delay))
        }
        if particles.count > 50 {
            particles.removeFirst(particles.count - 50)
        }
    }

    private func spawnParticlesForResults() {
        let total = engine.roundResults.reduce(0) { acc, r in
            acc + r.mainPoints + r.rejectedPoints + r.bonusPoints
        }
        spawnParticleBurst(count: min(total, 20))
    }

    private func clearParticles() {
        particles.removeAll()
    }

    // MARK: - UI helpers

    public func partidaTerminada() -> Bool {
        engine.phase.kind == .gameOver
    }
}
