# AGENTS.md — CardGameKit

## Contexto

Este package es la capa visual completa para juegos de baraja española. La app solo aporta reglas. Lee `Sources/CardGameKit/Protocols/` para entender los contratos antes de tocar nada.

---

## Para implementar un juego nuevo

1. **Crea los tipos de dominio** en la app (fase, acción, resultado, jugador) y confórmalos a los protocolos del package.

2. **Crea el engine** conformando `CardGameEngine`. Los nombres de los métodos mutantes del protocol (`executeDecision`, `executeDiscard`, `executeAction`, `newHand`) pueden ser wrappers de los métodos internos del engine — no hace falta renombrar nada, solo añadir la conformance en extensión.

3. **Crea el punto de entrada** con `CardTableView<TuEngine>(engineFactory:botDecider:humanName:bubbleProvider:)`. El `botDecider` es una closure que recibe un snapshot del engine y el asiento, y devuelve `BotMove<Action>`.

4. **Añade el package al `.xcodeproj`** como local package dependency con `relativePath = Packages/CardGameKit`. Ver `Ordago.xcodeproj/project.pbxproj` como referencia exacta de los bloques necesarios.

---

## Reglas que no son obvias en el código

- `Seat.bottom` es **siempre** el humano. El `botDecider` nunca recibe `.bottom`.
- `Rank` en el package no tiene ordenación ni valores de juego. Añádelos por extensión en la app.
- `Seat` no tiene propiedad `team`. Cada juego la define por extensión.
- Las imágenes de la baraja se cargan de `Bundle.module` — no copies assets a la app.
- `cornerRadius` de `SpanishCardImage` debe pasarse como `cardWidth * 0.06` para que escale bien en iPad.
- El `botDecider` closure **no** debe referenciar `BotStrategy` ni tipos internos del engine directamente — debe ser autocontenido o delegar a una función libre.

---

## Qué NO tocar en el package

- No añadir lógica de ningún juego concreto a ningún archivo bajo `Sources/CardGameKit/`.
- No añadir propiedades a `Rank`, `Seat`, `Card` o `Deck` que sean específicas de un juego.
- No cambiar la firma de ningún protocolo sin actualizar **todas** las conformances existentes (empezando por `MusEngine`, `GamePhase`, `BetAction`, `LanceResult`, `Player` en Ordago).
