import SwiftUI

/// Generic card fan view. Accepts any content for each card via a `@ViewBuilder` closure.
/// Deal animations and matched geometry effects are handled by the caller.
public struct CardFanView<CardContent: View>: View {
    let cardCount: Int
    let cardWidth: CGFloat
    let geometry: CardFanGeometry
    let cardContent: (Int) -> CardContent

    public init(
        cardCount: Int,
        cardWidth: CGFloat,
        geometry: CardFanGeometry = .init(),
        @ViewBuilder cardContent: @escaping (Int) -> CardContent
    ) {
        self.cardCount = cardCount
        self.cardWidth = cardWidth
        self.geometry = geometry
        self.cardContent = cardContent
    }

    public var body: some View {
        ZStack {
            ForEach(0..<cardCount, id: \.self) { idx in
                let angle = geometry.angle(at: idx, of: cardCount)
                let xOff = geometry.xOffset(at: idx, of: cardCount, cardWidth: cardWidth)
                let yOff = geometry.yOffset(at: idx, of: cardCount)

                cardContent(idx)
                    .frame(width: cardWidth)
                    .rotationEffect(.degrees(angle), anchor: .bottom)
                    .offset(x: xOff, y: yOff)
                    .zIndex(Double(idx))
            }
        }
    }
}
