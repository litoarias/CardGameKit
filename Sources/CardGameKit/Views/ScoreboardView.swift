import SwiftUI

/// Top scoreboard: Home  1 · PHASE · 4  Away
public struct ScoreboardView: View {
    let scoreHome: Int
    let scoreAway: Int
    let homeTeamName: String
    let awayTeamName: String
    var phaseLabel: String = "JUEGO"

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var scale: CGFloat { sizeClass == .regular ? 1.5 : 1.0 }

    public init(
        scoreHome: Int,
        scoreAway: Int,
        homeTeamName: String,
        awayTeamName: String,
        phaseLabel: String = "JUEGO"
    ) {
        self.scoreHome = scoreHome
        self.scoreAway = scoreAway
        self.homeTeamName = homeTeamName
        self.awayTeamName = awayTeamName
        self.phaseLabel = phaseLabel
    }

    public var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(homeTeamName)
                    .font(.system(size: 12 * scale, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(scoreHome)")
                    .font(.system(size: 20 * scale, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.4), value: scoreHome)
            }
            .frame(maxWidth: .infinity)
            .padding(.leading, 16 * scale)

            HStack(spacing: 6) {
                Text("–")
                    .font(.system(size: 17 * scale, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Text(phaseLabel)
                    .font(.system(size: 11 * scale, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8 * scale).padding(.vertical, 4 * scale)
                    .background(Capsule().fill(.yellow))
                    .animation(.easeInOut(duration: 0.3), value: phaseLabel)
                Text("–")
                    .font(.system(size: 17 * scale, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 4)

            HStack(spacing: 6) {
                Text("\(scoreAway)")
                    .font(.system(size: 20 * scale, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.4), value: scoreAway)
                Spacer()
                Text(awayTeamName)
                    .font(.system(size: 12 * scale, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.trailing, 16 * scale)
        }
        .padding(.vertical, 8 * scale)
        .background(RoundedRectangle(cornerRadius: max(8, 12 * scale)).fill(.black.opacity(0.45)))
    }
}
