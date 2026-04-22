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
    private let botDecider: @MainActor (Seat, Engine) async -> BotMove<Engine.Action>
    private let engineFactory: @MainActor () -> Engine
    /// Optional provider for seat speech bubbles (game-specific announcements).
    public let bubbleProvider: (@MainActor (Seat, Engine) -> String?)?

    // MARK: - Bot/thinking state

    public private(set) var isThinking: Bool = false
    public private(set) var thinkingSeat: Seat? = nil
    public private(set) var lastBotAction: String? = nil
    public private(set) var animationTrigger: Int = 0
    /// Incremented externally to force the action bar to re-evaluate legalActions().
    public var actionBarRefreshID: Int = 0

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

    // MARK: - Game over overlay

    public private(set) var showGameOver: Bool = false
    public private(set) var gameOverHomeScore: Int = 0
    public private(set) var gameOverAwayScore: Int = 0
    /// Accumulates results per hand across the whole game for the end summary.
    public private(set) var gameHistory: [[Engine.Result]] = []

    // MARK: - Human timer

    public private(set) var humanTimerActive: Bool = false
    public let turnTimerDuration: TimeInterval
    public let botThinkDuration: TimeInterval
    private var turnTimerTask: Task<Void, Never>?

    // MARK: - Drive task (stored to allow cancellation)

    private var driveTask: Task<Void, Never>?
    /// True once the initial deal + driveLoop has been kicked off.
    private var started = false

    // MARK: - Human interaction state

    public var selectedDiscardIndices: Set<Int> = []
    /// Indices of cards visually "lifted" for bot discard preview.
    public private(set) var botDiscardIndices: [Seat: Set<Int>] = [:]
    /// Card indices currently animating back to the deck (discard return phase).
    public private(set) var returningToDeck: [Seat: Set<Int>] = [:]
    /// Card indices hidden (not yet re-dealt) after a discard swap.
    public private(set) var hiddenAfterDiscard: [Seat: Set<Int>] = [:]
    public var humanName: String

    // MARK: - Particles

    public private(set) var particles: [Particle] = []

    // MARK: - Computed helpers

    public var isHumanTurn: Bool { engine.turnSeat == .bottom }

    // MARK: - Init

    public init(
        engineFactory: @escaping @MainActor () -> Engine,
        botDecider: @escaping @MainActor (Seat, Engine) async -> BotMove<Engine.Action>,
        humanName: String = "Jugador",
        turnTimerDuration: TimeInterval = 22,
        botThinkDuration: TimeInterval = 0.7,
        bubbleProvider: (@MainActor (Seat, Engine) -> String?)? = nil
    ) {
        self.engineFactory = engineFactory
        self.engine = engineFactory()
        self.botDecider = botDecider
        self.humanName = humanName
        self.turnTimerDuration = turnTimerDuration
        self.botThinkDuration = botThinkDuration
        self.bubbleProvider = bubbleProvider
    }

    // MARK: - Human actions

    /// Prevents double-tap from firing duplicate actions.
    private var processingAction = false

    public func humanDecision(_ agrees: Bool) {
        guard !isDealing, !processingAction else { return }
        processingAction = true
        defer { processingAction = false }
        stopHumanTimer()
        engine.executeDecision(seat: .bottom, agrees: agrees)
        animationTrigger += 1
        scheduleDriveLoop()
    }

    public func humanConfirmDiscard() {
        guard !isDealing, !processingAction else { return }
        processingAction = true
        stopHumanTimer()
        let indices = selectedDiscardIndices
        selectedDiscardIndices = []
        driveTask?.cancel()
        driveTask = Task { [weak self] in
            guard let self else { return }
            await animateDiscardSequence(seat: .bottom, indices: indices)
            processingAction = false
            await driveLoop()
        }
    }

    public func humanExecute(_ action: Engine.Action) {
        guard !isDealing, !processingAction else { return }
        processingAction = true
        defer { processingAction = false }
        stopHumanTimer()
        engine.executeAction(action)
        animationTrigger += 1
        spawnParticleBurst(count: action.particleBurst)
        scheduleDriveLoop()
    }

    public func mostrarResumen() {
        showRoundSummary = true
    }

    public func continuarDesdeSummary() {
        showRoundSummary = false
        summaryContinuation?.resume()
        summaryContinuation = nil
    }

    /// Hides the round summary overlay without advancing to the next hand.
    public func dismissSummaryOverlay() {
        showRoundSummary = false
    }

    /// Called by an external trigger (e.g. multiplayer host advancing) to dismiss
    /// whatever blocking overlay is active (summary or game-over).
    public func externalResume() {
        if showGameOver {
            dismissGameOver()
        } else {
            // Always resume the hand-end continuation — the driveLoop blocks on
            // it regardless of whether the summary overlay is visible.
            continuarDesdeSummary()
        }
    }

    public func dismissGameOver() {
        showGameOver = false
        newGame()
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
        botDiscardIndices = [:]
        returningToDeck = [:]
        hiddenAfterDiscard = [:]
        gameHistory = []
        showGameOver = false
        driveTask?.cancel()
        driveTask = Task { [weak self] in
            guard let self else { return }
            await animateDeal()
            await driveLoop()
        }
    }

    // MARK: - Internal drive scheduling

    private func scheduleDriveLoop() {
        driveTask?.cancel()
        driveTask = Task { [weak self] in
            guard let self else { return }
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
                gameOverHomeScore = engine.scores[.home] ?? 0
                gameOverAwayScore = engine.scores[.away] ?? 0
                showGameOver = true
                break loop

            case .handEnd:
                spawnParticlesForResults()
                summaryResults = engine.roundResults
                // Accumulate hand results for the end-of-game summary
                if !engine.roundResults.isEmpty {
                    gameHistory.append(engine.roundResults)
                }
                summaryScoreHome = engine.scores[.home] ?? 0
                summaryScoreAway = engine.scores[.away] ?? 0
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    self.summaryContinuation = cont
                }
                clearParticles()
                startNewHand()
                return

            case .discard:
                // Process discards in turn order from mano.
                // When it's the human's turn, break and wait for input.
                let result = await processDiscardsInOrder()
                if result == .waitingForHuman {
                    startHumanTimer()
                    break loop
                }
                // All discarded — phase will transition, continue loop
                continue loop

            case .decision:
                if isHumanTurn {
                    startHumanTimer()
                    break loop
                }
                isThinking = true
                thinkingSeat = engine.turnSeat
                try? await Task.sleep(for: .milliseconds(randomBotDelay(for: engine.phase.kind)))
                await processBotTurn()
                thinkingSeat = nil
                isThinking = false
                animationTrigger += 1

            case .bet:
                // Settle the deck off-screen once betting/lances begin
                settleDeck()
                // Auto-advance phases with no interaction (e.g. skipped lance)
                if engine.phaseRequiresAutoAdvance {
                    try? await Task.sleep(for: .milliseconds(3500))
                    engine.autoAdvancePhase()
                    animationTrigger += 1
                    continue loop
                }
                if isHumanTurn {
                    startHumanTimer()
                    break loop
                }
                isThinking = true
                thinkingSeat = engine.turnSeat
                try? await Task.sleep(for: .milliseconds(randomBotDelay(for: engine.phase.kind)))
                await processBotTurn()
                thinkingSeat = nil
                isThinking = false
                animationTrigger += 1
            }
        }
    }

    // MARK: - Discard coordination

    private enum DiscardResult { case waitingForHuman, allDone }

    /// Process discards in turn order from mano. Returns `.waitingForHuman` when
    /// it's the human's turn to discard, `.allDone` when all players have discarded.
    private func processDiscardsInOrder() async -> DiscardResult {
        // Build turn order starting from mano
        var order: [Seat] = []
        var s = engine.manoSeat
        for _ in 0..<4 { order.append(s); s = s.next }

        for seat in order {
            guard engine.phase.kind == .discard else { return .allDone }
            guard engine.pendingDiscardSeats.contains(seat) else { continue }
            if seat == .bottom { return .waitingForHuman }
            // Bot discard with lift preview then card-by-card animation
            isThinking = true
            thinkingSeat = seat
            let move = await botDecider(seat, engine)
            guard case .discard(let indices) = move else {
                thinkingSeat = nil; isThinking = false; continue
            }
            // Lift preview
            botDiscardIndices[seat] = indices
            animationTrigger += 1
            try? await Task.sleep(for: .milliseconds(600))
            botDiscardIndices[seat] = nil

            let player = engine.player(at: seat)
            lastBotAction = "\(player.name) descarta \(indices.count)"

            // Animated discard sequence (return → swap → deal)
            await animateDiscardSequence(seat: seat, indices: indices)

            animationTrigger += 1
            thinkingSeat = nil
            isThinking = false
            try? await Task.sleep(for: .milliseconds(200))
        }
        return .allDone
    }

    // MARK: - Discard animation (card-by-card)

    /// Animates a discard sequence for one seat:
    /// 1. Return discarded cards to the deck one by one
    /// 2. Execute the engine discard (swap cards)
    /// 3. Deal new cards back one by one
    private func animateDiscardSequence(seat: Seat, indices: Set<Int>) async {
        guard !indices.isEmpty else {
            engine.executeDiscard(seat: seat, indices: indices)
            return
        }
        let sorted = indices.sorted()

        // Phase 1: Return cards to deck one by one
        for idx in sorted {
            withAnimation(.spring(duration: 0.35, bounce: 0.12)) {
                if returningToDeck[seat] == nil { returningToDeck[seat] = [] }
                returningToDeck[seat]?.insert(idx)
            }
            try? await Task.sleep(for: .milliseconds(180))
        }
        try? await Task.sleep(for: .milliseconds(120))

        // Phase 2: Swap cards in the engine, but hide new cards
        hiddenAfterDiscard[seat] = indices
        returningToDeck[seat] = nil
        engine.executeDiscard(seat: seat, indices: indices)
        animationTrigger += 1

        // Phase 3: Deal new cards back one by one
        try? await Task.sleep(for: .milliseconds(180))
        for idx in sorted {
            withAnimation(.spring(duration: 0.45, bounce: 0.25)) {
                hiddenAfterDiscard[seat]?.remove(idx)
            }
            try? await Task.sleep(for: .milliseconds(160))
        }
        hiddenAfterDiscard[seat] = nil
    }

    // MARK: - Bot coordination

    private func processBotDiscards() async {
        // Process bots in turn order from mano (next seats after mano)
        let botSeats: [Seat] = {
            var seats: [Seat] = []
            var s = engine.manoSeat
            for _ in 0..<4 {
                if s != .bottom { seats.append(s) }
                s = s.next
            }
            return seats
        }()
        for seat in botSeats {
            guard engine.phase.kind == .discard else { return }
            guard engine.pendingDiscardSeats.contains(seat) else { continue }
            isThinking = true
            thinkingSeat = seat
            // Decide which cards to discard
            let move = await botDecider(seat, engine)
            guard case .discard(let indices) = move else {
                thinkingSeat = nil
                isThinking = false
                continue
            }
            // Visually lift selected cards
            botDiscardIndices[seat] = indices
            animationTrigger += 1
            // Hold the lift animation so the user can see it
            try? await Task.sleep(for: .milliseconds(900))
            // Execute the discard
            let player = engine.player(at: seat)
            lastBotAction = "\(player.name) descarta \(indices.count)"
            botDiscardIndices[seat] = nil
            engine.executeDiscard(seat: seat, indices: indices)
            animationTrigger += 1
            thinkingSeat = nil
            isThinking = false
            // Brief pause between bots so the user can follow the sequence
            try? await Task.sleep(for: .milliseconds(300))
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
        turnTimerTask = Task { [weak self] in
            guard let self else { return }
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
            humanConfirmDiscard()
        case .bet:
            let actions = engine.legalActions()
            if let first = actions.first { humanExecute(first) }
        default:
            break
        }
    }

    // MARK: - Start (idempotent)

    /// Kicks off the initial deal animation + drive loop exactly once.
    /// Safe to call multiple times (e.g. from SwiftUI `.task` on a view that
    /// might be recreated) — subsequent calls are no-ops.
    public func startIfNeeded() async {
        guard !started else { return }
        started = true
        await animateDeal()
        await driveLoop()
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
        // Keep the deck visible at the centre during decision/discard phases
        // (e.g. Mus rounds). It will be settled off-screen when betting begins.
        let shouldSettle = engine.phase.kind != .decision && engine.phase.kind != .discard
        if shouldSettle {
            withAnimation(.spring(duration: 0.7, bounce: 0.2)) {
                deckSettled = true
            }
        }
    }

    /// Hides the deck pile by animating it off-screen to the mano corner.
    public func settleDeck() {
        guard !deckSettled else { return }
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
        botDiscardIndices = [:]
        returningToDeck = [:]
        hiddenAfterDiscard = [:]
        dealAnimationID += 1
        dealRevealedCount = 0
        isDealing = true
        driveTask?.cancel()
        driveTask = Task { [weak self] in
            guard let self else { return }
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

    // MARK: - Bot timing

    /// Random thinking delay that varies by phase to feel human.
    /// Kept short (0.5–1.5 s) so games feel snappy; the engine-level
    /// bot strategy adds its own delay on top.
    private func randomBotDelay(for phase: PhaseKind) -> Int {
        switch phase {
        case .decision:
            return Int.random(in: 500...1000)
        case .bet:
            return Int.random(in: 600...1200)
        default:  // discard, etc.
            return Int.random(in: 500...1000)
        }
    }

    // MARK: - UI helpers

    public func partidaTerminada() -> Bool {
        engine.phase.kind == .gameOver
    }
}
