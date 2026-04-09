# CardGameKit

A Swift Package that sets the table. You bring the game engine, this handles the cards, animations, scoreboard and buttons.

Built for [Órdago](https://github.com/litoarias/Ordago), a Mus card game for iOS, but designed for any Spanish deck card game.

---

## What's included

- 4-player table with animated card fans
- Deal animation
- Scoreboard with phase display
- Context-sensitive action bar
- Round summary overlay
- Scoring particles (the chickpeas in Mus)
- Turn timer for the human player
- Full Spanish deck assets (40 cards + back)

Everything is driven by `CardTableViewModel`. You just conform your game's types to the protocols.

---

## Requirements

- iOS 18+ / macOS 15+
- Swift 6 with strict concurrency

No third-party dependencies. Apple frameworks only.

---

## Installation

In Xcode: **File → Add Package Dependencies** and point to this repo.

---

## Basic usage

### 1. Conform your game types

```swift
import CardGameKit

extension MyPhase: CardGamePhase {
    var kind: PhaseKind { ... }
    var displayName: String { ... }
    var gameOverWinner: TeamSide? { ... }
}

extension MyAction: CardGameAction {
    var displayText: String { ... }
    var buttonColor: Color { ... }
    var particleBurst: Int { 0 }
}

extension MyEngine: CardGameEngine {
    static var winningScore: Int { 30 }
    static func teamName(for side: TeamSide) -> String { ... }
    static var decisionLabels: (agree: String, disagree: String) { ("Yes", "No") }
    // + the mutating protocol methods
}
```

### 2. Show the table

```swift
struct MyGameView: View {
    var body: some View {
        CardTableView<MyEngine>(
            engineFactory: { MyEngine() },
            botDecider: { seat, engine in
                await MyBot().decide(engine: engine, seat: seat)
            }
        )
    }
}
```

That's it. The package handles everything else.

---

## Card assets

40 cards in `Cards.xcassets`, named `{rank}_{suit}` — e.g. `1_oros`, `sota_copas`, `rey_espadas` — plus `reverso`. Loaded via `Bundle.module`, no need to copy anything to your app target.

Card images sourced from [Wikimedia Commons](https://commons.wikimedia.org/wiki/Category:Spanish_playing_cards), available under Creative Commons licensing.

---

## Tests

```bash
swift test
```

28 tests across 6 suites: Suit, Rank, Card, Deck, Seat and CardFanGeometry.
