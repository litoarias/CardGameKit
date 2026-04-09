import SwiftUI

/// Renders a Spanish deck card using images from the CardGameKit resource bundle.
public struct SpanishCardImage: View {
    let card: Card?
    let faceDown: Bool
    /// Corner radius in points. Pass `cardWidth * 0.06` for proportional scaling.
    let cornerRadius: CGFloat

    public init(card: Card?, faceDown: Bool = false, cornerRadius: CGFloat = 8) {
        self.card = card
        self.faceDown = faceDown
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        let name = (faceDown || card == nil) ? "reverso" : (card?.assetName ?? "reverso")
        Image(name, bundle: .module)
            .resizable()
            .interpolation(.high)
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.5), radius: 3, x: 1, y: 2)
    }
}
