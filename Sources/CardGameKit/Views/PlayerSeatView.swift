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
        teamColor: Color = .blue
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
                    .overlay(alignment: .trailing) {
                        bubbleView.offset(x: bubbleOutwardOffset)
                    }
                playerBadge
            }
        case .left:
            VStack(spacing: 4) {
                fanCards
                    .overlay(alignment: .leading) {
                        bubbleView.offset(x: -bubbleOutwardOffset)
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

    private var bubbleOutwardOffset: CGFloat { 16 }

    // MARK: - Speech bubble

    @ViewBuilder
    private var bubbleView: some View {
        if let bubbleText, !bubbleText.isEmpty {
            Text(bubbleText)
                .font(.callout.bold())
                .foregroundStyle(.black)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(.white))
                .overlay(Capsule().stroke(.gray.opacity(0.3), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                .transition(.scale.combined(with: .opacity))
        }
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

                SpanishCardImage(card: card, faceDown: dealt ? !revealCards : true,
                                 cornerRadius: cardWidth * 0.06)
                    .frame(width: cardWidth)
                    .rotationEffect(.degrees(dealt ? angle : 0), anchor: .bottom)
                    .scaleEffect(dealt ? 1.0 : 0.35)
                    .offset(
                        x: dealt ? xOff : corrected.width,
                        y: dealt ? fanGeo.yOffset(at: idx, of: count) : corrected.height
                    )
                    .opacity(dealt ? 1 : 0)
                    .zIndex(dealt ? Double(idx) : -1)
                    .matchedGeometryEffect(
                        id: "\(player.id)-\(idx)-\(dealAnimationID)",
                        in: namespace
                    )
                    .transition(.scale(scale: 0.25).combined(with: .opacity))
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
    private var manoIconSize: CGFloat { max(7, cardWidth * 0.12) }
    private var manoOffset: CGFloat { max(3, cardWidth * 0.07) }

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
                        // Solid white border — always visible when active
                        Circle()
                            .stroke(Color.white, lineWidth: 2.5)
                            .padding(-5)
                            .opacity(isCurrent ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 0.20), value: isCurrent)

                        // Sonar pulse — expands and fades outward
                        Circle()
                            .stroke(Color.white.opacity((1 - pulseProgress) * 0.70), lineWidth: 2)
                            .scaleEffect(1.0 + pulseProgress * 1.60)
                            .padding(-5)
                    }
                if isMano {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: manoIconSize, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(2)
                        .background(Circle().fill(Color.yellow))
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
        .scaleEffect(isCurrent ? 1.1 : 1.0)
        .animation(.spring(duration: 0.3), value: isCurrent)
        .task(id: isCurrent) {
            guard isCurrent else {
                withAnimation(.none) { pulseProgress = 0.0 }
                return
            }
            // Sonar sweep loop: expand ring from badge edge, fade to invisible, reset instantly
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
