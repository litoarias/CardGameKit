import SwiftUI

/// Main game table view. Generic over any `CardGameEngine`.
/// Inject an `engineFactory`, a `botDecider`, and optional customizations.
public struct CardTableView<Engine: CardGameEngine>: View {
    @State private var vm: CardTableViewModel<Engine>
    @Namespace private var dealNS
    @AppStorage("isPro") private var isPro = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    /// Pass the envite stepper amount here so the action bar re-renders when it changes.
    var actionBarRefreshTrigger: Int = 0
    /// Increment externally to auto-dismiss the summary or game-over overlay.
    /// Used in multiplayer so the host can drag guests past blocking screens.
    var externalResumeTrigger: Int = 0
    /// Optional custom background that replaces the default green felt gradient.
    var customBackground: AnyView?
    /// Called when the round summary overlay appears or disappears.
    var onSummaryVisible: ((Bool) -> Void)?
    /// Optional action for the exit/close button embedded in the scoreboard header.
    var onExit: (() -> Void)?
    /// Optional custom action bar builder. When provided, replaces the default `ActionBarView`.
    var actionBarBuilder: ((@MainActor (CardTableViewModel<Engine>, Bool) -> AnyView))?
    /// When false the built-in phase indicator capsule in the centre of the table is hidden,
    /// letting the caller supply its own richer overlay instead.
    var showPhaseIndicator: Bool = true

    private var scoreboardScale: CGFloat { sizeClass == .regular ? 1.5 : 1.0 }

    public init(
        actionBarRefreshTrigger: Int = 0,
        externalResumeTrigger: Int = 0,
        engineFactory: @escaping @MainActor () -> Engine,
        botDecider: @escaping @MainActor (Seat, Engine) async -> BotMove<Engine.Action>,
        humanName: String = "Jugador",
        turnTimerDuration: TimeInterval = 10,
        bubbleProvider: (@MainActor (Seat, Engine) -> String?)? = nil,
        background: AnyView? = nil,
        showPhaseIndicator: Bool = true,
        onSummaryVisible: ((Bool) -> Void)? = nil,
        onExit: (() -> Void)? = nil,
        actionBarBuilder: ((@MainActor (CardTableViewModel<Engine>, Bool) -> AnyView))? = nil
    ) {
        self.actionBarRefreshTrigger = actionBarRefreshTrigger
        self.externalResumeTrigger = externalResumeTrigger
        self.customBackground = background
        self.showPhaseIndicator = showPhaseIndicator
        self.onSummaryVisible = onSummaryVisible
        self.onExit = onExit
        self.actionBarBuilder = actionBarBuilder
        _vm = State(initialValue: CardTableViewModel(
            engineFactory: engineFactory,
            botDecider: botDecider,
            humanName: humanName,
            turnTimerDuration: turnTimerDuration,
            bubbleProvider: bubbleProvider
        ))
    }

    /// Init that receives a pre-created ViewModel. Use this when the caller
    /// manages ViewModel lifetime externally (e.g. multiplayer guest) to prevent
    /// SwiftUI from recreating the VM on every body re-evaluation.
    public init(
        viewModel: CardTableViewModel<Engine>,
        actionBarRefreshTrigger: Int = 0,
        externalResumeTrigger: Int = 0,
        background: AnyView? = nil,
        showPhaseIndicator: Bool = true,
        onSummaryVisible: ((Bool) -> Void)? = nil,
        onExit: (() -> Void)? = nil,
        actionBarBuilder: ((@MainActor (CardTableViewModel<Engine>, Bool) -> AnyView))? = nil
    ) {
        _vm = State(initialValue: viewModel)
        self.actionBarRefreshTrigger = actionBarRefreshTrigger
        self.externalResumeTrigger = externalResumeTrigger
        self.customBackground = background
        self.showPhaseIndicator = showPhaseIndicator
        self.onSummaryVisible = onSummaryVisible
        self.onExit = onExit
        self.actionBarBuilder = actionBarBuilder
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let safeBottom = geo.safeAreaInsets.bottom
            let bannerH: CGFloat = isPro ? 0 : 50
            let h = geo.size.height + (isPro ? safeBottom : 0) - bannerH
            // In landscape size cards off height; in portrait off width
            let isLandscape = w > geo.size.height
            let botCardW: CGFloat = isLandscape ? h * 0.13 : w * 0.144
            let humanCardW: CGFloat = isLandscape ? h * 0.20 : w * 0.216
            // In landscape the action panel floats over the bottom-right corner — it does NOT
            // shift the play area, so everything stays centred on the full width.
            let actionPanelW: CGFloat = 140   // used only to position the floating panel
            let centerX: CGFloat = w / 2
            // Scoreboard adaptive height
            let sbHalfH: CGFloat = 19 * scoreboardScale
            let scoreboardY: CGFloat = sbHalfH + 4
            let scoreboardBottom: CGFloat = sbHalfH * 2 + 4
            // Human hand: lower in landscape to open up the centre of the table
            let humanHandY: CGFloat = isLandscape ? h * 0.78 : h * 0.80
            // Top seat: below scoreboard with gap
            let topSeatY = topSeatCenter(h: h, botCardW: botCardW, scoreboardBottom: scoreboardBottom)
            // Left/right seats: high enough to leave air above human hand
            let leftRightY = min(h * 0.43, humanHandY - humanCardW * 0.85 - botCardW * 1.3 - 24)
            // Human badge: just below the card fan
            let humanBadgeY = isLandscape
                ? humanHandY + humanCardW * 0.85 + 18
                : max(h * 0.81, min(h * 0.93, humanHandY + humanCardW * 0.85 + 16))
            // Action bar Y only used in portrait
            let actionBarY = h + 14

            ZStack {
                // Background — use custom if provided, otherwise the default green felt gradient
                Group {
                    if let custom = customBackground {
                        custom
                    } else {
                        tableBackground
                    }
                }
                .ignoresSafeArea()

                // Scoreboard spans full width — acts as header in both orientations
                ScoreboardView(
                    scoreHome: vm.engine.scores[.home] ?? 0,
                    scoreAway: vm.engine.scores[.away] ?? 0,
                    homeTeamName: Engine.teamName(for: .home),
                    awayTeamName: Engine.teamName(for: .away),
                    phaseLabel: vm.engine.phase.displayName,
                    onExit: onExit
                )
                .frame(width: w * 0.9)
                .position(x: w / 2, y: scoreboardY)

                // Partner (top) — centred in the play area
                seatView(.top, cardW: botCardW, tableSize: geo.size)
                    .position(x: centerX, y: topSeatY)

                // Left bot
                seatView(.left, cardW: botCardW, tableSize: geo.size)
                    .position(x: w * 0.17, y: leftRightY)

                // Right bot
                seatView(.right, cardW: botCardW, tableSize: geo.size)
                    .position(x: w * 0.83, y: leftRightY)

                // Deck pile (centre during deal, settles to mano corner)
                let mano = vm.engine.manoSeat
                let settledPos = deckSettledPosition(mano: mano, w: w, h: h, humanHandY: humanHandY)
                let settledScale = deckSettledScale(mano: mano, botCardW: botCardW, humanCardW: humanCardW)
                deckPile(cardW: botCardW, layerRotations: vm.deckLayerRotations)
                    .scaleEffect(vm.deckSettled ? settledScale : 1.15)
                    .rotationEffect(.degrees(vm.deckSettled ? vm.deckRotation : -4))
                    .position(vm.deckSettled ? settledPos : CGPoint(x: centerX, y: h * 0.45))
                    .animation(.spring(duration: 0.7, bounce: 0.15), value: vm.deckSettled)
                    .animation(.spring(duration: 0.7, bounce: 0.15), value: mano.rawValue)

                // Particles
                ParticleLayer(particles: vm.particles)

                // Phase indicator (centre of table) — hidden when the caller supplies its own
                if showPhaseIndicator {
                    phaseIndicator
                        .position(x: centerX, y: h * 0.54)
                }

                // Human hand fan (bottom)
                humanHandFan(cardW: humanCardW, tableSize: geo.size)
                    .position(x: centerX, y: humanHandY)

                // Human speech bubble
                humanBubble(cardW: humanCardW)
                    .position(x: centerX, y: humanHandY - humanCardW * 0.85 - 10)

                // Human badge
                humanBadge(cardW: humanCardW)
                    .position(x: centerX, y: humanBadgeY)

                // Action buttons — vertical panel on right edge in landscape, bottom bar in portrait
                if let builder = actionBarBuilder {
                    if isLandscape {
                        VStack {
                            Spacer()
                            builder(vm, true)
                                .frame(width: actionPanelW - 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.black.opacity(0.30))
                                )
                                .padding(.bottom, 16)
                        }
                        .frame(width: actionPanelW, height: h)
                        .position(x: w - actionPanelW / 2, y: h / 2)
                    } else {
                        builder(vm, false)
                            .frame(width: w * 0.9)
                            .position(x: w / 2, y: actionBarY)
                    }
                } else {
                    if isLandscape {
                        VStack {
                            Spacer()
                            ActionBarView(vm: vm, vertical: true)
                                .frame(width: actionPanelW - 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.black.opacity(0.30))
                                )
                                .padding(.bottom, 16)
                        }
                        .frame(width: actionPanelW, height: h)
                        .position(x: w - actionPanelW / 2, y: h / 2)
                    } else {
                        ActionBarView(vm: vm)
                            .frame(width: w * 0.9)
                            .position(x: w / 2, y: actionBarY)
                    }
                }

                // Round summary overlay
                if vm.showRoundSummary {
                    RoundSummaryView(
                        results: vm.summaryResults,
                        scoreHome: vm.summaryScoreHome,
                        scoreAway: vm.summaryScoreAway,
                        homeTeamName: Engine.teamName(for: .home),
                        awayTeamName: Engine.teamName(for: .away),
                        winningScore: Engine.winningScore,
                        onDismiss: vm.dismissSummaryOverlay
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    // Reserve space for the ad banner so the panel centres itself
                    // in the visible area above the banner, not the full screen height.
                    .padding(.bottom, bannerH)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(50)
                }

                // Game-over banner — compact, centred, does not cover player card fans
                if vm.showGameOver {
                    let homeWins = vm.gameOverHomeScore >= Engine.winningScore
                    let winnerName = Engine.teamName(for: homeWins ? .home : .away)
                    let winnerColor: Color = homeWins ? .blue : .orange
                    GameOverBanner(
                        winnerName: winnerName,
                        winnerColor: winnerColor,
                        homeTeamName: Engine.teamName(for: .home),
                        awayTeamName: Engine.teamName(for: .away),
                        homeScore: vm.gameOverHomeScore,
                        awayScore: vm.gameOverAwayScore,
                        winningScore: Engine.winningScore,
                        gameHistory: vm.gameHistory,
                        onNewGame: vm.dismissGameOver
                    )
                    .frame(maxWidth: min(w * 0.58, 300))
                    .position(x: centerX, y: h * 0.50)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                    .zIndex(40)
                }
            }
            .animation(.spring(duration: 0.35), value: vm.showRoundSummary)
        .animation(.spring(duration: 0.45, bounce: 0.12), value: vm.showGameOver)
            .ignoresSafeArea(edges: .bottom)
        }
        .preferredColorScheme(.dark)
        .onChange(of: actionBarRefreshTrigger) { _, newVal in
            vm.actionBarRefreshID = newVal
        }
        .onChange(of: externalResumeTrigger) { _, _ in
            vm.externalResume()
        }
        .onChange(of: vm.showRoundSummary) { _, visible in
            onSummaryVisible?(visible)
        }
        .task {
            await vm.startIfNeeded()
        }
    }

    // MARK: - Phase indicator

    private var phaseIndicator: some View {
        let display = vm.engine.phase.displayName
        let isActive = vm.engine.phase.kind != .handEnd
        return Group {
            if isActive {
                Text(display)
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 6)
                    .background(Capsule().fill(Color(red: 0.1, green: 0.5, blue: 0.3)))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.4), value: vm.animationTrigger)
    }

    // MARK: - Seat views (bots + partner)

    @ViewBuilder
    private func seatView(_ seat: Seat, cardW: CGFloat, tableSize: CGSize) -> some View {
        let p = vm.engine.player(at: seat)
        let reveal = shouldRevealCards
        let orient: FanOrientation = switch seat {
        case .top: .down
        case .left: .right
        case .right: .left
        case .bottom: .up
        }
        let teamColor: Color = p.side == .home ? .blue : .orange

        PlayerSeatView(
            player: p,
            revealCards: reveal,
            isCurrent: vm.engine.turnSeat == seat,
            isMano: vm.engine.manoSeat == seat,
            bubbleText: vm.bubbleProvider?(seat, vm.engine),
            cardWidth: cardW,
            dealAnimationID: vm.dealAnimationID,
            namespace: dealNS,
            orientation: orient,
            dealRevealedCount: vm.dealRevealedCount,
            isDealing: vm.isDealing,
            seatDealOffset: seatDealOffset(seat),
            deckOffset: deckOffset(for: seat, size: tableSize),
            timerActive: vm.thinkingSeat == seat,
            timerDuration: vm.turnTimerDuration,
            teamColor: teamColor,
            liftedIndices: vm.botDiscardIndices[seat] ?? [],
            returningIndices: vm.returningToDeck[seat] ?? [],
            hiddenIndices: vm.hiddenAfterDiscard[seat] ?? []
        )
    }

    // MARK: - Human hand fan

    private func humanHandFan(cardW: CGFloat, tableSize: CGSize) -> some View {
        let cards = vm.engine.player(at: .bottom).cards
        let count = cards.count
        let fanGeo = CardFanGeometry(spreadAngle: 18, overlapRatio: 0.60)
        let offset = deckOffset(for: .bottom, size: tableSize)

        return ZStack {
            ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                let angle = fanGeo.angle(at: idx, of: count)
                let xOff = fanGeo.xOffset(at: idx, of: count, cardWidth: cardW)
                let selected = vm.selectedDiscardIndices.contains(idx)
                let order = vm.dealOrder(for: .bottom, cardIndex: idx)
                let dealt = order < vm.dealRevealedCount
                let returning = vm.returningToDeck[.bottom]?.contains(idx) ?? false
                let hidden = vm.hiddenAfterDiscard[.bottom]?.contains(idx) ?? false
                let visible = dealt && !returning && !hidden

                SpanishCardImage(card: card, faceDown: visible ? false : true, cornerRadius: cardW * 0.06)
                    .frame(width: cardW)
                    .rotationEffect(.degrees(visible ? angle : 0), anchor: .bottom)
                    .scaleEffect(visible ? (selected ? 1.08 : 1.0) : 0.35)
                    .offset(
                        x: visible ? xOff : offset.width,
                        y: visible
                            ? (selected ? -40 : fanGeo.yOffset(at: idx, of: count) * 2)
                            : offset.height
                    )
                    .opacity(visible ? 1 : 0)
                    .zIndex(selected ? 10 : (visible ? Double(idx) : -1))
                    .matchedGeometryEffect(id: "human-\(idx)-\(vm.dealAnimationID)", in: dealNS)
                    .shadow(color: selected ? .white.opacity(0.6) : .clear, radius: 8)
                    .transition(.scale(scale: 0.25).combined(with: .opacity))
                    .animation(.spring(duration: 0.25), value: selected)
                    .onTapGesture { toggleDiscard(idx) }
            }
        }
        .animation(.spring(duration: 0.38, bounce: 0.18), value: cards.map(\.id))
        .frame(height: cardW * 1.7)
    }

    private func toggleDiscard(_ idx: Int) {
        guard vm.engine.phase.kind == .discard else { return }
        withAnimation(.spring(duration: 0.25)) {
            if vm.selectedDiscardIndices.contains(idx) {
                vm.selectedDiscardIndices.remove(idx)
            } else {
                vm.selectedDiscardIndices.insert(idx)
            }
        }
    }

    // MARK: - Deck pile

    private func deckPile(cardW: CGFloat, layerRotations: [Double]) -> some View {
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                SpanishCardImage(card: nil, faceDown: true, cornerRadius: cardW * 0.06)
                    .frame(width: cardW)
                    .rotationEffect(.degrees(layerRotations[i]))
                    .offset(x: CGFloat(i) * 0.7, y: -CGFloat(i) * 0.7)
            }
        }
    }

    // MARK: - Human badge

    @State private var humanPulseProgress: Double = 0

    private func humanBadge(cardW: CGFloat) -> some View {
        let iconSize = max(16, cardW * 0.24)
        let circlePad = max(3, cardW * 0.05)
        let manoSize = max(22, cardW * 0.36)
        let manoOff = max(14, cardW * 0.26)
        let isMano = vm.engine.manoSeat == .bottom
        let isTurn = vm.engine.turnSeat == .bottom
        return HStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: iconSize))
                    .foregroundStyle(.white)
                    .padding(circlePad)
                    .background(Circle().fill(.blue))
                    .overlay {
                        CountdownRingView(
                            duration: vm.turnTimerDuration,
                            lineWidth: 3,
                            color: .green,
                            isActive: vm.humanTimerActive
                        )
                        .padding(-2)
                    }
                    .overlay {
                        Circle()
                            .stroke(Color.yellow, lineWidth: 3)
                            .padding(-5)
                            .opacity(isTurn ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 0.20), value: isTurn)

                        Circle()
                            .stroke(Color.yellow.opacity(0.5), lineWidth: 6)
                            .blur(radius: 4)
                            .padding(-5)
                            .opacity(isTurn ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 0.20), value: isTurn)

                        Circle()
                            .stroke(Color.yellow.opacity((1 - humanPulseProgress) * 0.70), lineWidth: 2.5)
                            .scaleEffect(1.0 + humanPulseProgress * 1.60)
                            .padding(-5)
                    }
                if isMano {
                    Text("\u{270B}")
                        .font(.system(size: manoSize))
                        .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                        .offset(x: manoOff, y: -manoOff)
                }
            }
            Text(vm.humanName)
                .font(.caption.bold()).foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(isTurn ? Color.blue.opacity(0.85) : .black.opacity(0.55)))
                .animation(.easeInOut(duration: 0.20), value: isTurn)
        }
        .scaleEffect(isTurn ? 1.15 : 1.0)
        .animation(.spring(duration: 0.3), value: isTurn)
        .task(id: isTurn) {
            guard isTurn else {
                withAnimation(.none) { humanPulseProgress = 0.0 }
                return
            }
            while !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.90)) { humanPulseProgress = 1.0 }
                try? await Task.sleep(for: .seconds(1.20))
                guard !Task.isCancelled else { break }
                withAnimation(.none) { humanPulseProgress = 0.0 }
                try? await Task.sleep(for: .seconds(0.05))
            }
            withAnimation(.none) { humanPulseProgress = 0 }
        }
    }

    // MARK: - Human speech bubble

    @ViewBuilder
    private func humanBubble(cardW: CGFloat) -> some View {
        if let text = vm.bubbleProvider?(.bottom, vm.engine), !text.isEmpty {
            let fontSize = max(15, cardW * 0.22)
            let config = SpeechBubbleConfig.resolve(for: text)
            Text(text)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(config.fg)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Capsule().fill(config.bg))
                .overlay(Capsule().stroke(config.border, lineWidth: 1.5))
                .shadow(color: config.bg.opacity(0.55), radius: 8, y: 3)
                .transition(.scale(scale: 0.7).combined(with: .opacity))
                .animation(.spring(duration: 0.25, bounce: 0.3), value: text)
        }
    }

    // MARK: - Layout helpers

    private var tableBackground: some View {
        LinearGradient(
            colors: [Color(red: 0.07, green: 0.42, blue: 0.22),
                     Color(red: 0.03, green: 0.28, blue: 0.14)],
            startPoint: .top, endPoint: .bottom
        )
    }

    private var shouldRevealCards: Bool {
        let kind = vm.engine.phase.kind
        return kind == .handEnd || kind == .gameOver
    }

    private func deckSettledPosition(mano: Seat, w: CGFloat, h: CGFloat, humanHandY: CGFloat) -> CGPoint {
        switch mano {
        case .bottom: return CGPoint(x: -w * 0.05, y: humanHandY)
        case .top:    return CGPoint(x: w * 1.05,  y: h * 0.08)
        case .left:   return CGPoint(x: -w * 0.05, y: h * 0.45)
        case .right:  return CGPoint(x: w * 1.05,  y: h * 0.45)
        }
    }

    private func deckSettledScale(mano: Seat, botCardW: CGFloat, humanCardW: CGFloat) -> CGFloat {
        mano == .bottom ? (humanCardW / botCardW) * 1.2 : 1.2
    }

    private func deckOffset(for seat: Seat, size: CGSize) -> CGSize {
        let w = size.width
        let bannerH: CGFloat = isPro ? 0 : 50
        let h = size.height - bannerH
        let sbHalfH: CGFloat = 19 * scoreboardScale
        let sbBottom: CGFloat = sbHalfH * 2 + 4
        let isLandscape = size.width > size.height
        let botCardW: CGFloat = isLandscape ? h * 0.13 : w * 0.144
        let humanCardW: CGFloat = isLandscape ? h * 0.20 : w * 0.216
        let humanHandY: CGFloat = isLandscape ? h * 0.78 : h * 0.73
        let lrY = min(h * 0.43, humanHandY - humanCardW * 0.85 - botCardW * 1.3 - 24)
        let deckCenter = CGPoint(x: w / 2, y: h * 0.45)
        let badge: CGFloat = 13
        let fanCenter: CGPoint = switch seat {
        case .bottom: CGPoint(x: w / 2, y: humanHandY)
        case .top:    CGPoint(x: w / 2, y: topSeatCenter(h: h, botCardW: botCardW, scoreboardBottom: sbBottom) + badge)
        case .left:   CGPoint(x: w * 0.17, y: lrY - badge)
        case .right:  CGPoint(x: w * 0.83, y: lrY - badge)
        }
        return CGSize(width: deckCenter.x - fanCenter.x, height: deckCenter.y - fanCenter.y)
    }

    /// Adaptive Y centre for the top seat, ensuring it never overlaps the scoreboard.
    private func topSeatCenter(h: CGFloat, botCardW: CGFloat, scoreboardBottom: CGFloat) -> CGFloat {
        let badgeH = max(22, botCardW * 0.39)  // mirrors PlayerSeatView badge scaling
        let seatHalfH = (badgeH + 4 + botCardW * 1.6) / 2
        return max(h * 0.16, scoreboardBottom + 20 + seatHalfH)
    }

    private func seatDealOffset(_ seat: Seat) -> Int {
        switch seat {
        case .bottom: 0
        case .right:  1
        case .top:    2
        case .left:   3
        }
    }
}
