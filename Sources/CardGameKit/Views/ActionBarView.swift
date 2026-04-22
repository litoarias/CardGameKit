import SwiftUI

/// Action button bar for the human player.
/// Generic over any `CardGameEngine` — drives layout from `PhaseKind`.
/// In landscape the caller passes `vertical: true` to stack buttons in a column.
public struct ActionBarView<Engine: CardGameEngine>: View {
    @Bindable var vm: CardTableViewModel<Engine>
    var vertical: Bool = false

    public init(vm: CardTableViewModel<Engine>, vertical: Bool = false) {
        self.vm = vm
        self.vertical = vertical
    }

    private var layout: AnyLayout {
        vertical ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
    }

    public var body: some View {
        Group {
            switch vm.engine.phase.kind {
            case .decision where vm.isHumanTurn:
                layout {
                    actionButton(Engine.decisionLabels.agree, color: .green) {
                        vm.humanDecision(true)
                    }
                    actionButton(Engine.decisionLabels.disagree, color: .orange) {
                        vm.humanDecision(false)
                    }
                }

            case .discard where vm.engine.pendingDiscardSeats.contains(.bottom):
                layout {
                    if vm.selectedDiscardIndices.isEmpty {
                        actionButton("Paso", color: .orange) {
                            vm.humanConfirmDiscard()
                        }
                    } else {
                        actionButton("Descartar (\(vm.selectedDiscardIndices.count))", color: .green) {
                            vm.humanConfirmDiscard()
                        }
                    }
                }

            case .bet where vm.isHumanTurn:
                let _ = vm.actionBarRefreshID  // track so buttons re-render when stepper changes
                let actions = vm.engine.legalActions()
                layout {
                    ForEach(actions, id: \.self) { action in
                        actionButton(action.displayText, color: action.buttonColor) {
                            vm.humanExecute(action)
                        }
                    }
                }

            case .handEnd:
                layout {
                    actionButton("Ver resumen", color: .white.opacity(0.18)) {
                        vm.mostrarResumen()
                    }
                    actionButton("Nueva mano", color: .green) {
                        vm.continuarDesdeSummary()
                    }
                }

            case .gameOver:
                layout {
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
