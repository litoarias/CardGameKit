import SwiftUI

/// Compact end-of-game overlay shown in the centre of the table.
/// Positioned so it does NOT cover the player card fans at the edges.
public struct GameOverBanner<Result: CardGameRoundResult>: View {
    let winnerName: String
    let winnerColor: Color
    let homeTeamName: String
    let awayTeamName: String
    let homeScore: Int
    let awayScore: Int
    let winningScore: Int
    let gameHistory: [[Result]]
    let onNewGame: () -> Void

    public init(
        winnerName: String,
        winnerColor: Color,
        homeTeamName: String,
        awayTeamName: String,
        homeScore: Int,
        awayScore: Int,
        winningScore: Int,
        gameHistory: [[Result]],
        onNewGame: @escaping () -> Void
    ) {
        self.winnerName = winnerName
        self.winnerColor = winnerColor
        self.homeTeamName = homeTeamName
        self.awayTeamName = awayTeamName
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.winningScore = winningScore
        self.gameHistory = gameHistory
        self.onNewGame = onNewGame
    }

    @State private var appeared = false

    private var handsPlayed: Int { gameHistory.count }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .foregroundStyle(.yellow)
                    .font(.system(size: 16, weight: .bold))
                Text("Fin de Partida")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 14).padding(.bottom, 8)

            Divider().overlay(.white.opacity(0.12))

            // Score row
            HStack(spacing: 0) {
                teamScore(name: homeTeamName, score: homeScore, isWinner: homeScore >= winningScore, color: .blue)
                Text("—")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(width: 28)
                teamScore(name: awayTeamName, score: awayScore, isWinner: awayScore >= winningScore, color: .orange)
            }
            .padding(.vertical, 12)

            // Hands count
            if handsPlayed > 0 {
                Text("\(handsPlayed) \(handsPlayed == 1 ? "mano" : "manos") jugadas")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.40))
                    .padding(.bottom, 10)
            }

            Divider().overlay(.white.opacity(0.12))

            // Nueva partida button
            Button(action: onNewGame) {
                Text("Nueva partida")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.white))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(red: 0.04, green: 0.20, blue: 0.12).opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(winnerColor.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.60), radius: 20, y: 6)
        )
        .scaleEffect(appeared ? 1 : 0.85)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(duration: 0.45, bounce: 0.18), value: appeared)
        .onAppear { appeared = true }
    }

    private func teamScore(name: String, score: Int, isWinner: Bool, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color.opacity(0.80))
                .lineLimit(1)
            Text("\(score)")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(isWinner ? color : .white.opacity(0.55))
        }
        .frame(minWidth: 72)
    }
}
