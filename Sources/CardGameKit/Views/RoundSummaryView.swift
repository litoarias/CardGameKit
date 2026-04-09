import SwiftUI

/// Overlay showing the hand/round summary: sections, points, and score progress.
/// Generic over any `CardGameRoundResult`.
public struct RoundSummaryView<Result: CardGameRoundResult>: View {
    let results: [Result]
    let scoreHome: Int
    let scoreAway: Int
    let homeTeamName: String
    let awayTeamName: String
    let winningScore: Int
    let onContinue: () -> Void

    public init(
        results: [Result],
        scoreHome: Int,
        scoreAway: Int,
        homeTeamName: String,
        awayTeamName: String,
        winningScore: Int,
        onContinue: @escaping () -> Void
    ) {
        self.results = results
        self.scoreHome = scoreHome
        self.scoreAway = scoreAway
        self.homeTeamName = homeTeamName
        self.awayTeamName = awayTeamName
        self.winningScore = winningScore
        self.onContinue = onContinue
    }

    @State private var appeared = false

    private var totalHome: Int {
        results.filter { $0.winner == .home }.reduce(0) { acc, r in acc + r.totalPoints }
    }
    private var totalAway: Int {
        results.filter { $0.winner == .away }.reduce(0) { acc, r in acc + r.totalPoints }
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection
                Divider().overlay(.white.opacity(0.10))
                resultRows
                Divider().overlay(.white.opacity(0.10))
                totalsSection
                Divider().overlay(.white.opacity(0.10))
                continueButton
            }
            .background(cardBackground)
            .padding(.horizontal, 28)
            .scaleEffect(appeared ? 1 : 0.93)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(duration: 0.4, bounce: 0.12), value: appeared)
        }
        .onAppear { appeared = true }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text("Fin de Mano")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Spacer()
            handWinnerBadge
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var handWinnerBadge: some View {
        if totalHome > totalAway {
            winnerBadge(name: homeTeamName, color: .blue)
        } else if totalAway > totalHome {
            winnerBadge(name: awayTeamName, color: .orange)
        }
    }

    private func winnerBadge(name: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill").font(.caption2)
            Text(name).font(.caption.bold())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.18)))
    }

    // MARK: - Result rows

    private var resultRows: some View {
        VStack(spacing: 0) {
            ForEach(0..<results.count, id: \.self) { idx in
                let result = results[idx]
                ResultSummaryRow(
                    result: result,
                    homeTeamName: homeTeamName,
                    awayTeamName: awayTeamName
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
                .animation(
                    .spring(duration: 0.38).delay(Double(idx) * 0.07 + 0.08),
                    value: appeared
                )
                if idx < results.count - 1 {
                    Divider().overlay(.white.opacity(0.07)).padding(.horizontal, 20)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Totals + score progress

    private var totalsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                teamPointsView(name: homeTeamName, points: totalHome,
                               isWinner: totalHome > totalAway, color: .blue)
                Spacer()
                Text("esta mano")
                    .font(.caption2).foregroundStyle(.white.opacity(0.30))
                Spacer()
                teamPointsView(name: awayTeamName, points: totalAway,
                               isWinner: totalAway > totalHome, color: .orange)
            }
            .padding(.horizontal, 24)

            scoreProgressSection
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 14)
        .opacity(appeared ? 1 : 0)
        .animation(
            .spring(duration: 0.38).delay(Double(results.count) * 0.07 + 0.15),
            value: appeared
        )
    }

    private func teamPointsView(name: String, points: Int, isWinner: Bool, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(name).font(.caption2).foregroundStyle(color.opacity(0.75))
            Text("+\(points)")
                .font(.title2.bold())
                .foregroundStyle(isWinner && points > 0 ? color : .white.opacity(0.45))
        }
    }

    private var scoreProgressSection: some View {
        VStack(spacing: 6) {
            scoreBar(name: homeTeamName, score: scoreHome, color: .blue)
            scoreBar(name: awayTeamName, score: scoreAway, color: .orange)
        }
    }

    private func scoreBar(name: String, score: Int, color: Color) -> some View {
        let fraction = min(Double(score) / Double(winningScore), 1.0)
        return HStack(spacing: 8) {
            Text(name)
                .font(.caption2.bold()).foregroundStyle(color)
                .frame(width: 56, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule().fill(color)
                        .frame(width: geo.size.width * fraction)
                        .animation(.spring(duration: 0.6).delay(0.15), value: fraction)
                }
            }
            .frame(height: 5)
            Text("\(score)/\(winningScore)")
                .font(.caption2).foregroundStyle(.white.opacity(0.50))
                .frame(width: 40, alignment: .trailing)
        }
    }

    // MARK: - Continue button

    private var continueButton: some View {
        Button(action: onContinue) {
            Text("Continuar")
                .font(.headline).foregroundStyle(.black)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 14).fill(.white))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20).padding(.vertical, 16)
        .opacity(appeared ? 1 : 0)
        .animation(
            .easeIn(duration: 0.25).delay(Double(results.count) * 0.07 + 0.28),
            value: appeared
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color(red: 0.04, green: 0.20, blue: 0.12))
            .overlay(RoundedRectangle(cornerRadius: 24)
                .strokeBorder(.white.opacity(0.10), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.55), radius: 40, y: 10)
    }
}

// MARK: - ResultSummaryRow

private struct ResultSummaryRow<Result: CardGameRoundResult>: View {
    let result: Result
    let homeTeamName: String
    let awayTeamName: String

    private var winnerName: String { result.winner == .home ? homeTeamName : awayTeamName }
    private var winnerColor: Color { result.winner == .home ? .blue : .orange }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(result.sectionName)
                    .font(.subheadline.bold()).foregroundStyle(.white)

                HStack(spacing: 4) {
                    if result.mainPoints > 0 {
                        pointTag(label: "Envite", value: result.mainPoints, color: .yellow)
                    }
                    if result.rejectedPoints > 0 {
                        pointTag(label: "No Querido", value: result.rejectedPoints, color: .red)
                    }
                    if result.bonusPoints > 0 {
                        pointTag(label: "Bonus", value: result.bonusPoints, color: .green)
                    }
                }

                Spacer()

                HStack(spacing: 5) {
                    Circle().fill(winnerColor).frame(width: 7, height: 7)
                    Text(winnerName).font(.caption.bold()).foregroundStyle(winnerColor)
                    Group {
                        if result.totalPoints > 0 {
                            Text("\(result.totalPoints)pt")
                        } else {
                            Text("—").foregroundStyle(.white.opacity(0.35))
                        }
                    }
                    .font(.subheadline.bold()).foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 11)
    }

    private func pointTag(label: String, value: Int, color: Color) -> some View {
        Text("\(label) \(value)")
            .font(.caption2.bold()).foregroundStyle(color)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
    }
}
