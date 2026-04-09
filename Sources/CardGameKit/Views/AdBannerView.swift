import SwiftUI

/// Placeholder for an ad banner (bottom strip).
/// Replace with the actual ad SDK view when integrating advertising.
public struct AdBannerView: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(Color.black.opacity(0.85))
            .overlay {
                Text("Publicidad")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
    }
}
