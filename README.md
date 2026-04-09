# CardGameKit

A Swift Package providing the **complete visual layer** for Spanish deck (baraja española) card games on iOS. Drop in your game engine and get a fully-animated card table for free.

---

## What it looks like

### iPhone — Mus game

```
┌─────────────────────────────┐
│  Nosotros  0 ─[GRANDE]─ 0  Rivales  │  ← ScoreboardView
│                             │
│       [🂠][🂠][🂠][🂠]         │  ← Partner (top seat)
│                             │
│  [🂠][🂠]           [🂠][🂠]  │  ← Left / Right bots
│  JonJimenez         Inovato │
│           🪙🪙🪙             │  ← ParticleLayer (garbanzos)
│                             │
│   [🂡][🂢][🂣][🂤][🂥]       │  ← Human hand fan (bottom)
│         HipolitoArias       │
│   [Paso] [Envido 2] [Órdago!]│  ← ActionBarView
│  ─────────────── Publicidad ─│  ← AdBannerView
└─────────────────────────────┘
```

### Round Summary overlay

```
┌────────────────────────────┐
│  Fin de Mano       👑 Nosotros │
├────────────────────────────┤
│  Grande    Envite 3     Nosotros  3pt │
│  Chica     No Querido 1  Rivales  1pt │
│  Pares     Bonus 2       Nosotros  2pt │
├────────────────────────────┤
│  Nosotros        esta mano        Rivales │
│    +5                               +1   │
│  ████████░░  12/30     ███░░  4/30  │
├────────────────────────────┤
│         [  Continuar  ]            │
└────────────────────────────┘
```

> **To add actual screenshots**: run the app in the iOS Simulator, take screenshots with `⌘ + S`, and place them in `docs/screenshots/`. Reference them in this README as `![iPhone gameplay](docs/screenshots/iphone_gameplay.png)`.

---

## Architecture overview

```
┌──────────────────────── CardGameKit (this package) ────────────────────────┐
│                                                                             │
│   Protocols ──────────────────────────────────────────────────────────────│
│   CardGameEngine ←── CardGamePhase, CardGameAction, CardGamePlayer,        │
│                       CardGameRoundResult                                  │
│                                                                             │
│   ViewModel ──────────────────────────────────────────────────────────────│
│   CardTableViewModel<Engine: CardGameEngine>                               │
│    ├── engine: Engine            (the game's state)                        │
│    ├── particles: [Particle]     (scoring tokens on table)                 │
│    ├── isDealing, dealRevealedCount, deckSettled  (deal animation)         │
│    ├── humanTimerActive          (10s countdown)                           │
│    └── driveLoop()               (game loop — drives bots, handles phases) │
│                                                                             │
│   Views ──────────────────────────────────────────────────────────────────│
│   CardTableView<Engine>                                                    │
│    ├── ScoreboardView            (top bar: scores + phase label)           │
│    ├── PlayerSeatView<Player>    (×3 bots: avatar + card fan)              │
│    ├── humanHandFan              (bottom: tappable cards for discard)      │
│    ├── deckPile                  (animates to mano corner after deal)      │
│    ├── ParticleLayer             (chickpea scoring tokens)                 │
│    ├── ActionBarView<Engine>     (context-sensitive action buttons)        │
│    ├── AdBannerView              (bottom strip, hidden when isPro)         │
│    └── RoundSummaryView<Result>  (modal after each hand)                   │
│                                                                             │
│   Shared Models ──────────────────────────────────────────────────────────│
│   Card, Suit, Rank, Deck, Seat, FanOrientation, Particle                  │
│   TeamSide, PhaseKind, BotMove<Action>                                     │
│                                                                             │
│   Assets ─────────────────────────────────────────────────────────────────│
│   Cards.xcassets — 40 Spanish deck cards + reverso (via Bundle.module)     │
└─────────────────────────────────────────────────────────────────────────────┘
           ▲                              ▲
           │ import CardGameKit           │ import CardGameKit
┌──────────┴──────────┐        ┌──────────┴──────────┐
│   Ordago (Mus app)  │        │ TrucoApp (future)   │
│                     │        │                     │
│ MusEngine           │        │ TrucoEngine         │
│ GamePhase → kind    │        │ TrucoPhase → kind   │
│ BetAction → color   │        │ TrucoAction → color │
│ LanceResult         │        │ TrucoResult         │
│ MusGameSetup.swift  │        │ TrucoGameSetup.swift│
└─────────────────────┘        └─────────────────────┘
```

---

## Quick start

### 1. Add the package to your Xcode project

In Xcode: **File → Add Package Dependencies → Add Local** → select `Packages/CardGameKit`.

Or manually in `project.pbxproj` (see [AGENTS.md](AGENTS.md) for the exact entries).

### 2. Conform your types

```swift
import CardGameKit

// Your game's phase
extension MyPhase: CardGamePhase {
    var kind: PhaseKind { ... }
    var displayName: String { ... }
    var gameOverWinner: TeamSide? { ... }
}

// Your game's actions (buttons)
extension MyAction: CardGameAction {
    var displayText: String { ... }
    var buttonColor: Color { ... }
    var particleBurst: Int { 0 }
}

// Your engine
extension MyEngine: CardGameEngine {
    static var winningScore: Int { 30 }
    static func teamName(for side: TeamSide) -> String { ... }
    static var decisionLabels: (agree: String, disagree: String) { ("Sí", "No") }
    // ... 6 mutating methods
}
```

### 3. Show the table

```swift
struct MyGameView: View {
    var body: some View {
        CardTableView<MyEngine>(
            engineFactory: { MyEngine() },
            botDecider: { seat, engine in
                let move = await MyBot().decide(engine: engine, seat: seat)
                return move
            }
        )
    }
}
```

That's it. The package handles everything else.

---

## API reference

### `CardGameEngine` protocol

```swift
// State (read-only)
var phase: Phase                        { get }
var turnSeat: Seat                      { get }
var manoSeat: Seat                      { get }
var scores: [TeamSide: Int]             { get }
var roundResults: [Result]              { get }
var pendingDiscardSeats: Set<Seat>      { get }

// Queries
func player(at seat: Seat) -> Player
func legalActions() -> [Action]

// Config (static)
static var winningScore: Int            { get }
static func teamName(for: TeamSide) -> String
static var decisionLabels: (agree: String, disagree: String) { get }

// Mutations
mutating func executeDecision(seat: Seat, agrees: Bool)
mutating func executeDiscard(seat: Seat, indices: Set<Int>)
mutating func executeAction(_ action: Action)
mutating func newHand()
```

### `CardGamePhase` protocol

```swift
var kind: PhaseKind           { get }   // drives ActionBarView layout
var displayName: String       { get }   // shown in scoreboard + phase indicator
var gameOverWinner: TeamSide? { get }   // non-nil only when kind == .gameOver
```

### `CardGameAction` protocol

```swift
var displayText: String  { get }  // button label
var buttonColor: Color   { get }  // button background
var particleBurst: Int   { get }  // 0=none, 3=small burst, 8=big burst
```

### `CardGamePlayer` protocol

```swift
var id: UUID               { get }
var name: String           { get }
var side: TeamSide         { get }
var cards: [Card]          { get }  // current hand
var avatarSystemImage: String { get }
var isHuman: Bool          { get }
```

### `CardGameRoundResult` protocol

```swift
var id: String          { get }  // must be unique within a round
var sectionName: String { get }  // section label in summary (e.g. "Grande")
var winner: TeamSide    { get }
var mainPoints: Int     { get }  // from accepted bets
var bonusPoints: Int    { get }  // from hand evaluation
var rejectedPoints: Int { get }  // from "no querido"
var totalPoints: Int    { get }
```

### `CardTableViewModel<Engine>` — key public API

```swift
// Engine access
var engine: Engine

// Human actions (called from your custom wrappers if needed)
func humanDecision(_ agrees: Bool)
func humanConfirmDiscard()
func humanExecute(_ action: Engine.Action)
func newGame()
func continuarDesdeSummary()

// Animation state (for custom views)
var isDealing: Bool
var dealRevealedCount: Int
var dealAnimationID: Int
var deckSettled: Bool

// Bot state
var isThinking: Bool
var thinkingSeat: Seat?
var lastBotAction: String?

// Particles
var particles: [Particle]

// Timer
var humanTimerActive: Bool
var turnTimerDuration: TimeInterval  // 10s
var botThinkDuration: TimeInterval   // 0.7s

// Summary
var showRoundSummary: Bool
var summaryResults: [Engine.Result]
var summaryScoreHome: Int
var summaryScoreAway: Int
```

### `SpanishCardImage`

```swift
SpanishCardImage(
    card: Card?,              // nil = show card back
    faceDown: Bool = false,
    cornerRadius: CGFloat = 8 // pass cardWidth * 0.06 for proportional corners
)
```

### `BotMove<Action>`

```swift
enum BotMove<Action: CardGameAction>: Sendable {
    case decision(Bool)       // agree (true) or disagree (false)
    case discard(Set<Int>)    // indices into the hand array
    case action(Action)       // any CardGameAction
}
```

---

## Shared models

### `Seat`

```
    .top
.left  .right
    .bottom  ← always the human player
```

```swift
Seat.bottom.next  // → .left
Seat.allCases     // [.bottom, .left, .top, .right]
```

> `.team` is NOT on Seat in the package. Each game defines team assignment via extension.

### `Rank`

```swift
// Package provides: cases + assetSuffix only
Rank.as_.assetSuffix   // "1"
Rank.sota.assetSuffix  // "sota"

// Your app adds: ordering and game values
extension Rank: Comparable { ... }
```

### `Deck`

```swift
var deck = Deck.spanish40()      // 40 cards
deck.shuffle(using: &rng)
let hand = deck.draw(4)          // [Card] × 4
deck.recycleAtBottom(discards)
```

### `TeamSide`

```swift
TeamSide.home   // the human's team (bottom + top)
TeamSide.away   // the opponent's team (left + right)
```

---

## Customisation points

### Speech bubbles (game-specific announcements)

```swift
CardTableView<MyEngine>(
    // ...
    bubbleProvider: { seat, engine in
        // Return a string to show in a speech bubble over that seat's cards
        // Return nil to show nothing
        if case .betting = engine.phase {
            return engine.player(at: seat).hasBet ? "Apuesto" : nil
        }
        return nil
    }
)
```

### Changing team names

```swift
extension MyEngine: CardGameEngine {
    static func teamName(for side: TeamSide) -> String {
        side == .home ? "Nosaltres" : "Ells"   // Valencian
    }
}
```

### Changing decision button labels

```swift
static var decisionLabels: (agree: String, disagree: String) {
    ("Truco", "Paso")
}
```

---

## Asset catalog

The package ships a 40-card Spanish deck in `Resources/Cards.xcassets`.

| Asset name pattern | Example |
|--------------------|---------|
| `{rank}_{suit}` | `1_oros`, `sota_copas`, `rey_espadas` |
| `reverso` | Card back |

Cards are loaded via `Bundle.module` — no need to copy assets to your app.

---

## Supported platforms

| Platform | Minimum |
|----------|---------|
| iOS | 18.0 |
| macOS | 15.0 (for `swift test` on Mac) |

---

## Running tests

```bash
cd Packages/CardGameKit
swift test
```

28 tests across 6 suites:
- `SuitTests` — 3 tests
- `RankTests` — 4 tests
- `CardTests` — 4 tests
- `DeckTests` — 6 tests
- `SeatTests` — 3 tests
- `CardFanGeometryTests` — 8 tests

---

## Project using this package

- **Ordago** — Mus card game (iOS)
  - Engine: `MusEngine` (30 piedras to win, 4 lances)
  - Entry point: `MusGameSetup.swift` → `MusGameView`

---

## Adding a screenshot to this README

1. Run the app in iOS Simulator
2. Take a screenshot: **⌘ + S** (saves to Desktop) or **Device → Take Screenshot**
3. Move to `Packages/CardGameKit/docs/screenshots/`
4. Replace the ASCII diagrams above with:

```markdown
![iPhone gameplay](docs/screenshots/iphone_gameplay.png)
![Round summary](docs/screenshots/round_summary.png)
![iPad layout](docs/screenshots/ipad_layout.png)
```

---

## For AI agents

See [AGENTS.md](AGENTS.md) for the complete step-by-step implementation guide, protocol signatures, common pitfalls, and `project.pbxproj` instructions.
