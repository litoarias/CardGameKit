import SwiftUI

/// Action button bar for the human player.
/// Generic over any `CardGameEngine` — drives layout from `PhaseKind`.
public struct ActionBarView<Engine: CardGameEngine>: View {
    @Bindable var vm: CardTableViewModel<Engine>

    public init(vm: CardTableViewModel<Engine>) {
        self.vm = vm
    }

    public var body: some View {
        Group {
            switch vm.engine.phase.kind {
            case .decision where vm.isHumanTurn:
                HStack(spacing: 12) {
                    actionButton(Engine.decisionLabels.agree, color: .green) {
                        vm.humanDecision(true)
                    }
                    actionButton(Engine.decisionLabels.disagree, color: .orange) {
                        vm.humanDecision(false)
                    }
                }

            case .discard where vm.engine.pendingDiscardSeats.contains(.bottom):
                HStack(spacing: 12) {
                    actionButton("Descartar (\(vm.selectedDiscardIndices.count))", color: .green) {
                        vm.humanConfirmDiscard()
                    }
                    .disabled(vm.selectedDiscardIndices.isEmpty)
                    .opacity(vm.selectedDiscardIndices.isEmpty ? 0.5 : 1.0)
                }

            case .bet where vm.isHumanTurn:
                let actions = vm.engine.legalActions()
                HStack(spacing: 10) {
                    ForEach(actions, id: \.self) { action in
                        actionButton(action.displayText, color: action.buttonColor) {
                            vm.humanExecute(action)
                        }
                    }
                }

            case .gameOver:
                HStack(spacing: 12) {
                    actionButton("Nueva partida", color: .green) {
                        vm.newGame()
                    }
                }

            default:
                if vm.isThinking {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white)
                        Text("Pensando...")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.7))
                    }
                    .frame(height: 44)
                } else if let msg = vm.lastBotAction {
                    Text(msg)
                        .font(.subheadline).foregroundStyle(.white.opacity(0.7))
                        .frame(height: 44)
                } else {
                    Spacer().frame(height: 44)
                }
            }
        }
    }

    private func actionButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 12).fill(color))
        }
        .buttonStyle(.plain)
    }
}
