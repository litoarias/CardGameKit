# AGENTS.md — CardGameKit

## Context

This package is the complete visual layer for Spanish deck card games. The app only provides the rules. Read `Sources/CardGameKit/Protocols/` to understand the contracts before touching anything.

---

## Implementing a new game

1. **Create your domain types** in the app (phase, action, result, player) and conform them to the package protocols.

2. **Create the engine** by conforming to `CardGameEngine`. The mutating protocol methods (`executeDecision`, `executeDiscard`, `executeAction`, `newHand`) can be wrappers around your engine's internal methods — no need to rename anything, just add the conformance in an extension.

3. **Create the entry point** with `CardTableView<YourEngine>(engineFactory:botDecider:humanName:bubbleProvider:)`. The `botDecider` is a closure that receives an engine snapshot and a seat, and returns `BotMove<Action>`.

4. **Add the package to `.xcodeproj`** as a local package dependency with `relativePath = Packages/CardGameKit`. See `Ordago.xcodeproj/project.pbxproj` for the exact blocks needed.

---

## Non-obvious rules

- `Seat.bottom` is **always** the human player. The `botDecider` never receives `.bottom`.
- `Rank` in the package has no ordering or game values. Add them via extension in the app.
- `Seat` has no `team` property. Each game defines it via extension.
- Card images are loaded from `Bundle.module` — do not copy assets to the app target.
- `cornerRadius` in `SpanishCardImage` should be passed as `cardWidth * 0.06` so it scales correctly on iPad.
- The `botDecider` closure should **not** reference `BotStrategy` or internal engine types directly — it must be self-contained or delegate to a free function.

---

## What NOT to touch in the package

- Do not add game-specific logic to any file under `Sources/CardGameKit/`.
- Do not add game-specific properties to `Rank`, `Seat`, `Card` or `Deck`.
- Do not change any protocol signature without updating **all** existing conformances (starting with `MusEngine`, `GamePhase`, `BetAction`, `LanceResult`, `Player` in Ordago).
