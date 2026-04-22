import SwiftUI

/// Shared color configuration for speech bubbles used across table views.
public struct SpeechBubbleConfig {
    public let bg: Color
    public let fg: Color
    public let border: Color

    public static func resolve(for text: String) -> SpeechBubbleConfig {
        let t = text.lowercased()
        if t.contains("órdago") || t.contains("ordago") {
            return SpeechBubbleConfig(bg: .red, fg: .white, border: .red.opacity(0.7))
        }
        if t.hasPrefix("envido") || t.hasPrefix("envite") {
            return SpeechBubbleConfig(bg: Color(red: 0.1, green: 0.7, blue: 0.3), fg: .white, border: .green.opacity(0.6))
        }
        if t == "quiero" {
            return SpeechBubbleConfig(bg: Color(red: 0.15, green: 0.55, blue: 1.0), fg: .white, border: .blue.opacity(0.5))
        }
        if t == "no quiero" {
            return SpeechBubbleConfig(bg: Color(red: 0.95, green: 0.45, blue: 0.1), fg: .white, border: .orange.opacity(0.5))
        }
        return SpeechBubbleConfig(bg: .white, fg: .black, border: .gray.opacity(0.25))
    }
}
