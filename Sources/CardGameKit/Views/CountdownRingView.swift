import SwiftUI

/// Animated ring that depletes clockwise over a given duration.
/// Wraps around a circular avatar to indicate remaining decision time.
public struct CountdownRingView: View {
    let duration: TimeInterval
    let lineWidth: CGFloat
    let color: Color
    let isActive: Bool

    public init(duration: TimeInterval, lineWidth: CGFloat, color: Color, isActive: Bool) {
        self.duration = duration
        self.lineWidth = lineWidth
        self.color = color
        self.isActive = isActive
    }

    @State private var progress: Double = 1.0
    @State private var timerTask: Task<Void, Never>?

    public var body: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(
                ringGradient,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .animation(.linear(duration: 0.1), value: progress)
            .onChange(of: isActive) { _, active in
                if active {
                    startCountdown()
                } else {
                    stopCountdown()
                }
            }
            .onAppear {
                if isActive { startCountdown() }
            }
            .onDisappear {
                timerTask?.cancel()
            }
    }

    private var ringGradient: some ShapeStyle {
        AngularGradient(
            colors: urgencyColors,
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360 * progress)
        )
    }

    private var urgencyColors: [Color] {
        if progress > 0.5 {
            return [color, color]
        } else if progress > 0.25 {
            return [.yellow, .orange]
        } else {
            return [.orange, .red]
        }
    }

    private func startCountdown() {
        timerTask?.cancel()
        progress = 1.0
        let steps = Int(duration * 10)
        timerTask = Task { @MainActor in
            for step in 1...steps {
                try? await Task.sleep(for: .milliseconds(100))
                if Task.isCancelled { return }
                progress = 1.0 - Double(step) / Double(steps)
            }
            progress = 0
        }
    }

    private func stopCountdown() {
        timerTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            progress = 1.0
        }
    }
}
