import SwiftUI

/// Main game table view. Generic over any `CardGameEngine`.
/// Inject an `engineFactory`, a `botDecider`, and optional customizations.
public struct CardTableView<Engine: CardGameEngine>: View {
    @State private var vm: CardTableViewModel<Engine>
    @Namespace private var dealNS
    @AppStorage("isPro") private var isPro = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var scoreboardScale: CGFloat { sizeClass == .regular ? 1.5 : 1.0 }

    public init(
        engineFactory: @escaping @MainActor () -> Engine,
        botDecider: @escaping @MainActor (Seat, Engine) async -> BotMove<Engine.Action>,
        humanName: String = "Jugador",
        turnTimerDuration: TimeInterval = 10,
        bubbleProvider: (@MainActor (Seat, Engine) -> String?)? = nil
    ) {
        _vm = State(initialValue: CardTableViewModel(
            engineFactory: engineFactory,
            botDecider: botDecider,
            humanName: humanName,
            turnTimerDuration: turnTimerDuration,
            bubbleProvider: bubbleProvider
        ))
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let safeBottom = geo.safeAreaInsets.bottom
            let bannerH: CGFloat = isPro ? 0 : 50
            let h = geo.size.height + (isPro ? safeBottom : 0) - bannerH
            let botCardW = w * 0.144
            let humanCardW = w * 0.216
            // Scoreboard adaptive height
            let sbHalfH: CGFloat = 19 * scoreboardScale
            let scoreboardY: CGFloat = sbHalfH + 4
            let scoreboardBottom: CGFloat = sbHalfH * 2 + 4
            // Top seat: below scoreboard with gap
            let topSeatY = topSeatCenter(h: h, botCardW: botCardW, scoreboardBottom: scoreboardBottom)
            // Left/right seats: high enough to leave air above human hand
            let leftRightY = min(h * 0.43, h * 0.73 - humanCardW * 0.85 - botCardW * 1.3 - 24)
            // Human badge: just below the card fan
            let humanBadgeY = max(h * 0.74, min(h * 0.90, h * 0.73 + humanCardW * 0.85 + 20))
            // Action bar: near the bottom of usable area
            let actionBarY = h - 28

            ZStack {
                // Green felt background
                tableBackground
                    .ignoresSafeArea()

                // Scoreboard (top center)
                ScoreboardView(
                    scoreHome: vm.engine.scores[.home] ?? 0,
                    scoreAway: vm.engine.scores[.away] ?? 0,
                    homeTeamName: Engine.teamName(for: .home),
                    awayTeamName: Engine.teamName(for: .away),
                    phaseLabel: vm.engine.phase.displayName
                )
                .frame(width: w * 0.9)
                .position(x: w / 2, y: scoreboardY)

                // Partner (top)
                seatView(.top, cardW: botCardW, tableSize: geo.size)
                    .position(x: w / 2, y: topSeatY)

                // Left bot
                seatView(.left, cardW: botCardW, tableSize: geo.size)
                    .position(x: w * 0.17, y: leftRightY)

                // Right bot
                seatView(.right, cardW: botCardW, tableSize: geo.size)
                    .position(x: w * 0.83, y: leftRightY)

                // Deck pile (center during deal, settles to mano corner)
                let mano = vm.engine.manoSeat
                let settledPos = deckSettledPosition(mano: mano, w: w, h: h)
                let settledScale = deckSettledScale(mano: mano, botCardW: botCardW, humanCardW: humanCardW)
                deckPile(cardW: botCardW, layerRotations: vm.deckLayerRotations)
                    .scaleEffect(vm.deckSettled ? settledScale : 1.15)
                    .rotationEffect(.degrees(vm.deckSettled ? vm.deckRotation : -4))
                    .position(vm.deckSettled ? settledPos : CGPoint(x: w / 2, y: h * 0.45))
                    .animation(.spring(duration: 0.7, bounce: 0.15), value: vm.deckSettled)
                    .animation(.spring(duration: 0.7, bounce: 0.15), value: mano.rawValue)

                // Particles
                ParticleLayer(particles: vm.particles)

                // Phase indicator (center of table)
                phaseIndicator
                    .position(x: w / 2, y: h * 0.54)

                // Human hand fan (bottom)
                humanHandFan(cardW: humanCardW, tableSize: geo.size)
                    .position(x: w / 2, y: h * 0.73)

                // Human badge
                humanBadge(cardW: humanCardW)
                    .position(x: w / 2, y: humanBadgeY)

                // Action buttons
                ActionBarView(vm: vm)
                    .frame(width: w * 0.9)
                    .position(x: w / 2, y: actionBarY)

                // Ad banner
                if !isPro {
                    AdBannerView()
                        .frame(maxWidth: .infinity).frame(height: bannerH)
                        .position(x: w / 2, y: geo.size.height + safeBottom - bannerH / 2)
                        .ignoresSafeArea(edges: .bottom)
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
                        onContinue: vm.continuarDesdeSummary
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(50)
                }
            }
            .animation(.spring(duration: 0.35), value: vm.showRoundSummary)
            .ignoresSafeArea(edges: .bottom)
        }
        .preferredColorScheme(.dark)
        .task {
            await vm.animateDeal()
            await vm.driveLoop()
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
            teamColor: teamColor
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

                SpanishCardImage(card: card, faceDown: !dealt, cornerRadius: cardW * 0.06)
                    .frame(width: cardW)
                    .rotationEffect(.degrees(dealt ? angle : 0), anchor: .bottom)
                    .scaleEffect(dealt ? (selected ? 1.08 : 1.0) : 0.35)
                    .offset(
                        x: dealt ? xOff : offset.width,
                        y: dealt
                            ? (selected ? -40 : fanGeo.yOffset(at: idx, of: count) * 2)
                            : offset.height
                    )
                    .opacity(dealt ? 1 : 0)
                    .zIndex(selected ? 10 : (dealt ? Double(idx) : -1))
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

    private func humanBadge(cardW: CGFloat) -> some View {
        let iconSize = max(16, cardW * 0.24)
        let circlePad = max(3, cardW * 0.05)
        let manoIconSize = max(8, cardW * 0.10)
        let manoOffset = max(4, cardW * 0.07)
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
                if vm.engine.manoSeat == .bottom {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: manoIconSize, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(2)
                        .background(Circle().fill(Color.yellow))
                        .offset(x: manoOffset, y: -manoOffset)
                }
            }
            Text(vm.humanName)
                .font(.caption.bold()).foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(.black.opacity(0.55)))
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

    private func deckSettledPosition(mano: Seat, w: CGFloat, h: CGFloat) -> CGPoint {
        switch mano {
        case .bottom: return CGPoint(x: -w * 0.05, y: h * 0.80)
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
        let botCardW = w * 0.144
        let humanCardW = w * 0.216
        let lrY = min(h * 0.43, h * 0.73 - humanCardW * 0.85 - botCardW * 1.3 - 24)
        let deckCenter = CGPoint(x: w / 2, y: h * 0.45)
        let badge: CGFloat = 13
        let fanCenter: CGPoint = switch seat {
        case .bottom: CGPoint(x: w / 2, y: h * 0.73)
        case .top:    CGPoint(x: w / 2, y: topSeatCenter(h: h, botCardW: botCardW, scoreboardBottom: sbBottom) + badge)
        case .left:   CGPoint(x: w * 0.17, y: lrY - badge)
        case .right:  CGPoint(x: w * 0.83, y: lrY - badge)
        }
        return CGSize(width: deckCenter.x - fanCenter.x, height: deckCenter.y - fanCenter.y)
    }

    /// Adaptive Y center for the top seat, ensuring it never overlaps the scoreboard.
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
