# CardGameKit

Swift Package que pone la mesa de juego. Tú traes el motor, esto pone las cartas, las animaciones, los marcadores y los botones.

Nació para [Órdago](https://github.com/litoarias/Ordago), un juego de Mus para iOS, pero está pensado para cualquier juego de cartas con baraja española.

---

## Qué incluye

- Mesa de 4 jugadores con fans de cartas animados
- Reparto con animación
- Marcador con fases
- Barra de acciones contextual
- Resumen de mano al acabar cada ronda
- Partículas de puntuación (los garbanzos del Mus)
- Temporizador para el jugador humano
- La baraja española completa en Assets (40 cartas + reverso)

Todo gestionado por `CardTableViewModel`. Tú solo conformas los protocolos de tu juego.

---

## Requisitos

- iOS 18+ / macOS 15+
- Swift 6

---

## Instalación

En Xcode: **File → Add Package Dependencies** y apunta a este repo.

---

## Uso básico

### 1. Conforma los protocolos de tu juego

```swift
import CardGameKit

extension MiPhase: CardGamePhase {
    var kind: PhaseKind { ... }
    var displayName: String { ... }
    var gameOverWinner: TeamSide? { ... }
}

extension MiAccion: CardGameAction {
    var displayText: String { ... }
    var buttonColor: Color { ... }
    var particleBurst: Int { 0 }
}

extension MiMotor: CardGameEngine {
    static var winningScore: Int { 30 }
    static func teamName(for side: TeamSide) -> String { ... }
    static var decisionLabels: (agree: String, disagree: String) { ("Sí", "No") }
    // + los métodos mutating del protocolo
}
```

### 2. Muestra la mesa

```swift
struct MiJuegoView: View {
    var body: some View {
        CardTableView<MiMotor>(
            engineFactory: { MiMotor() },
            botDecider: { seat, engine in
                await MiBot().decide(engine: engine, seat: seat)
            }
        )
    }
}
```

Listo. El paquete se encarga del resto.

---

## Baraja

40 cartas en `Cards.xcassets`, nombradas `{valor}_{palo}` — por ejemplo `1_oros`, `sota_copas`, `rey_espadas` — más `reverso`. Se cargan via `Bundle.module`, no necesitas copiar nada al app target.

---

## Tests

```bash
swift test
```

28 tests repartidos en 6 suites: Suit, Rank, Card, Deck, Seat y CardFanGeometry.
