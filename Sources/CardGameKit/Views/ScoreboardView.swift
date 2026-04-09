import SwiftUI

/// Top scoreboard: Home  1 · PHASE · 4  Away
public struct ScoreboardView: View {
    let scoreHome: Int
    let scoreAway: Int
    let homeTeamName: String
    let awayTeamName: String
    var phaseLabel: String = "JUEGO"

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
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text("\(scoreHome)")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.4), value: scoreHome)
            }
            .frame(maxWidth: .infinity)
            .padding(.leading, 16)

            HStack(spacing: 6) {
                Text("–")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.5))
                Text(phaseLabel)
                    .font(.caption2.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(.yellow))
                    .animation(.easeInOut(duration: 0.3), value: phaseLabel)
                Text("–")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 4)

            HStack(spacing: 6) {
                Text("\(scoreAway)")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.4), value: scoreAway)
                Spacer()
                Text(awayTeamName)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.trailing, 16)
        }
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.45)))
    }
}
