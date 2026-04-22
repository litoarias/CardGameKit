import SwiftUI

/// Seat view: avatar badge + card fan in the correct table orientation.
/// Generic over any `CardGamePlayer`.
public struct PlayerSeatView<Player: CardGamePlayer>: View {
    let player: Player
    let revealCards: Bool
    let isCurrent: Bool
    let isMano: Bool
    let bubbleText: String?
    let cardWidth: CGFloat
    let dealAnimationID: Int
    let namespace: Namespace.ID
    let orientation: FanOrientation
    var dealRevealedCount: Int = 16
    var isDealing: Bool = false
    var seatDealOffset: Int = 0
    var deckOffset: CGSize = .zero
    var timerActive: Bool = false
    var timerDuration: TimeInterval = 0.7
    /// Color representing the player's team (home = blue, away = orange by convention).
    var teamColor: Color = .blue
    /// Indices of cards visually "lifted" (bot discard preview). Empty by default.
    var liftedIndices: Set<Int> = []
    /// Indices of cards animating back to the deck (discard return phase).
    var returningIndices: Set<Int> = []
    /// Indices of cards hidden (not yet re-dealt) after a discard swap.
    var hiddenIndices: Set<Int> = []

    public init(
        player: Player,
        revealCards: Bool,
        isCurrent: Bool,
        isMano: Bool,
        bubbleText: String?,
        cardWidth: CGFloat,
        dealAnimationID: Int,
        namespace: Namespace.ID,
        orientation: FanOrientation,
        dealRevealedCount: Int = 16,
        isDealing: Bool = false,
        seatDealOffset: Int = 0,
        deckOffset: CGSize = .zero,
        timerActive: Bool = false,
        timerDuration: TimeInterval = 0.7,
        teamColor: Color = .blue,
        liftedIndices: Set<Int> = [],
        returningIndices: Set<Int> = [],
        hiddenIndices: Set<Int> = []
    ) {
        self.player = player
        self.revealCards = revealCards
        self.isCurrent = isCurrent
        self.isMano = isMano
        self.bubbleText = bubbleText
        self.cardWidth = cardWidth
        self.dealAnimationID = dealAnimationID
        self.namespace = namespace
        self.orientation = orientation
        self.dealRevealedCount = dealRevealedCount
        self.isDealing = isDealing
        self.seatDealOffset = seatDealOffset
        self.deckOffset = deckOffset
        self.timerActive = timerActive
        self.timerDuration = timerDuration
        self.teamColor = teamColor
        self.liftedIndices = liftedIndices
        self.returningIndices = returningIndices
        self.hiddenIndices = hiddenIndices
    }

    public var body: some View {
        layout
    }

    // MARK: - Layout by orientation

    @ViewBuilder
    private var layout: some View {
        switch orientation {
        case .down:
            VStack(spacing: 4) {
                playerBadge
                fanCards
                    .overlay(alignment: .bottom) {
                        bubbleView.offset(y: bubbleOutwardOffset)
                    }
            }
        case .right:
            VStack(spacing: 4) {
                fanCards
                    .overlay(alignment: .top) {
                        bubbleView.offset(y: -bubbleOutwardOffset)
                    }
                playerBadge
            }
        case .left:
            VStack(spacing: 4) {
                fanCards
                    .overlay(alignment: .top) {
                        bubbleView.offset(y: -bubbleOutwardOffset)
                    }
                playerBadge
            }
        case .up:
            VStack(spacing: 4) {
                fanCards
                    .overlay(alignment: .top) {
                        bubbleView.offset(y: -bubbleOutwardOffset)
                    }
                playerBadge
            }
        }
    }

    private var bubbleOutwardOffset: CGFloat { max(22, cardWidth * 0.4) }

    // MARK: - Speech bubble

    @ViewBuilder
    private var bubbleView: some View {
        if let bubbleText, !bubbleText.isEmpty {
            let config = bubbleConfig(for: bubbleText)
            Text(bubbleText)
                .font(.system(size: bubbleFontSize, weight: .bold))
                .foregroundStyle(config.fg)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Capsule().fill(config.bg))
                .overlay(Capsule().stroke(config.border, lineWidth: 1.5))
                .shadow(color: config.bg.opacity(0.55), radius: 8, y: 3)
                .transition(.scale(scale: 0.7).combined(with: .opacity))
                .animation(.spring(duration: 0.25, bounce: 0.3), value: bubbleText)
        }
    }

    private var bubbleFontSize: CGFloat { max(15, cardWidth * 0.28) }

    private func bubbleConfig(for text: String) -> SpeechBubbleConfig {
        SpeechBubbleConfig.resolve(for: text)
    }

    // MARK: - Card fan

    private var fanCards: some View {
        let count = player.cards.count
        let fanGeo = CardFanGeometry(spreadAngle: 20, overlapRatio: 0.40)

        let globalRotation: Double = switch orientation {
        case .down:  180
        case .right: 90
        case .left:  -90
        case .up:    0
        }

        let frameW: CGFloat
        let frameH: CGFloat
        switch orientation {
        case .up, .down:
            frameW = cardWidth * 2.6
            frameH = cardWidth * 1.6
        case .left, .right:
            frameW = cardWidth * 1.6
            frameH = cardWidth * 2.6
        }

        let corrected = correctedDeckOffset

        let cards = player.cards
        return ZStack {
            ForEach(0..<count, id: \.self) { idx in
                let card = cards[idx]
                let angle = fanGeo.angle(at: idx, of: count)
                let xOff = fanGeo.xOffset(at: idx, of: count, cardWidth: cardWidth)
                let order = idx * 4 + seatDealOffset
                let dealt = order < dealRevealedCount
                let lifted = liftedIndices.contains(idx)
                let returning = returningIndices.contains(idx)
                let hidden = hiddenIndices.contains(idx)
                let visible = dealt && !returning && !hidden

                SpanishCardImage(card: card, faceDown: visible ? !revealCards : true,
                                 cornerRadius: cardWidth * 0.06)
                    .frame(width: cardWidth)
                    .rotationEffect(.degrees(visible ? angle : 0), anchor: .bottom)
                    .scaleEffect(visible ? (lifted ? 1.08 : 1.0) : 0.35)
                    .offset(
                        x: visible ? xOff : corrected.width,
                        y: visible
                            ? (lifted ? fanGeo.yOffset(at: idx, of: count) - 20 : fanGeo.yOffset(at: idx, of: count))
                            : corrected.height
                    )
                    .opacity(visible ? 1 : 0)
                    .zIndex(lifted ? 10 : (visible ? Double(idx) : -1))
                    .shadow(color: lifted ? .white.opacity(0.5) : .clear, radius: 6)
                    .matchedGeometryEffect(
                        id: "\(player.id)-\(idx)-\(dealAnimationID)",
                        in: namespace
                    )
                    .transition(.scale(scale: 0.25).combined(with: .opacity))
                    .animation(.spring(duration: 0.25), value: lifted)
            }
        }
        .animation(.spring(duration: 0.38, bounce: 0.18), value: cards.map(\.id))
        .rotationEffect(.degrees(globalRotation))
        .frame(width: frameW, height: frameH)
    }

    private var correctedDeckOffset: CGSize {
        switch orientation {
        case .up:    return deckOffset
        case .down:  return CGSize(width: -deckOffset.width, height: -deckOffset.height)
        case .right: return CGSize(width: deckOffset.height, height: -deckOffset.width)
        case .left:  return CGSize(width: -deckOffset.height, height: deckOffset.width)
        }
    }

    // MARK: - Player badge

    private var badgeIconSize: CGFloat { max(12, cardWidth * 0.25) }
    private var badgeCirclePad: CGFloat { max(3, cardWidth * 0.07) }
    private var manoEmojiSize: CGFloat { max(20, cardWidth * 0.45) }
    private var manoOffset: CGFloat { max(14, cardWidth * 0.32) }

    @State private var pulseProgress: Double = 0

    private var playerBadge: some View {
        HStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: player.avatarSystemImage)
                    .font(.system(size: badgeIconSize))
                    .foregroundStyle(.white)
                    .padding(badgeCirclePad)
                    .background(Circle().fill(teamColor))
                    // ── Countdown ring (existing) ─────────────────────────
                    .overlay {
                        CountdownRingView(
                            duration: timerDuration,
                            lineWidth: 2,
                            color: .green,
                            isActive: timerActive
                        )
                        .padding(-1)
                    }
                    // ── Active player indicator ───────────────────────────
                    .overlay {
                        // Bright colored ring — always visible when active
                        Circle()
                            .stroke(Color.yellow, lineWidth: 3)
                            .padding(-5)
                            .opacity(isCurrent ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 0.20), value: isCurrent)

                        // Glow behind the ring
                        Circle()
                            .stroke(Color.yellow.opacity(0.5), lineWidth: 6)
                            .blur(radius: 4)
                            .padding(-5)
                            .opacity(isCurrent ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 0.20), value: isCurrent)

                        // Sonar pulse — expands and fades outward
                        Circle()
                            .stroke(Color.yellow.opacity((1 - pulseProgress) * 0.70), lineWidth: 2.5)
                            .scaleEffect(1.0 + pulseProgress * 1.60)
                            .padding(-5)
                    }
                if isMano {
                    Text("\u{270B}")
                        .font(.system(size: manoEmojiSize))
                        .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                        .offset(x: manoOffset, y: -manoOffset)
                }
            }
            Text(player.name)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(isCurrent ? teamColor.opacity(0.85) : .black.opacity(0.55))
                )
                .animation(.easeInOut(duration: 0.20), value: isCurrent)
        }
        .scaleEffect(isCurrent ? 1.15 : 1.0)
        .animation(.spring(duration: 0.3), value: isCurrent)
        .task(id: isCurrent) {
            guard isCurrent else {
                withAnimation(.none) { pulseProgress = 0.0 }
                return
            }
            while !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.90)) { pulseProgress = 1.0 }
                try? await Task.sleep(for: .seconds(1.20))
                guard !Task.isCancelled else { break }
                withAnimation(.none) { pulseProgress = 0.0 }
                try? await Task.sleep(for: .seconds(0.05))
            }
            withAnimation(.none) { pulseProgress = 0.0 }
        }
    }
}
