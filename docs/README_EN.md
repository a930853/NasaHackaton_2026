# Documentation (English)

**English** · [Español](README_ES.md)

Documentation for **Red Planet Survivors**, a cooperative Mars survival game for NASA Hackathon 2026. The Spanish originals are in [`es/`](README_ES.md); the project's front page is the [root README](../README.md).

**New here?** Start with the [project overview](en/overview.md): one page covering what the game is, how it is played, its event families and the NASA data it uses.

## Quick tour

1. **Play it:** <https://red-planet-survivors.karu.es/> (open it on a computer and join from phones).
2. **Watch it:** [20-second promo video](assets/promo-video.mp4).
3. **The idea:** [original proposal](proposal/proposal-en.pdf) (PDF).
4. **The game:** [project overview](en/overview.md).
5. **NASA data:** [overview › Word Book and data sources](en/overview.md#word-book-and-data-sources).
6. **How it is built:** [message protocol](en/protocol.md), then the guide for each component below.

## What to read

| If you want to… | Read |
|---|---|
| Know what the game is and how it is played | [Project overview](en/overview.md) |
| See which real NASA data it uses | [Overview › Word Book and data sources](en/overview.md#word-book-and-data-sources) |
| Understand the rules and why they are that way | [Game design](en/game-design.md) |
| See how Godot, the server and the phones talk | [Protocol](en/protocol.md) → [Godot networking](en/godot/networking.md) |
| Implement game logic in Godot | [Godot architecture](en/godot/architecture.md) |
| Work on the web controller | [Protocol](en/protocol.md) → [Controller](en/controller.md) |
| Work on the backend | [Protocol](en/protocol.md) → [Backend](en/backend.md) |
| Deploy it (Internet or local) | [Deployment](en/deploy.md) |

## Documents

```text
docs/
  README_EN.md         This page
  README_ES.md         The same index in Spanish
  en/
    overview.md          Summary of the submitted version: gameplay, events, Earth help, glossary and data sources
    protocol.md          Message contract between Godot, controllers and backend. Network source of truth.
    backend.md           Node server: structure, room model, reconnection and message logging
    controller.md        Web controller (Vue): role/NFC routes, states, session recovery and styling
    deploy.md            Coolify Internet deployment and local Docker deployment
    game-design.md       Rules: Sol loop, roles, resources, balance, objectives and design decisions
    event-catalog.md     Original design event catalog, with its NASA sources
    crew-availability.md Busy crew: how many Sols each task takes and what happens if the base is empty
    godot/
      architecture.md    Managers, state machine, models and events.json format
      networking.md      Net autoload, rooms, lobby, QR, views and choice validation
  es/                  Spanish documentation (same structure)
  assets/              UI sketch and promo video
  proposal/            Original hackathon proposal (PDF, English and Spanish)
```

## Sources of truth

- **Network messages:** [protocol.md](en/protocol.md). Agree on any change there first.
- **Event figures and numerical rules:** [`game/Data/events.json`](../game/Data/events.json) and the constants in `game/Scripts/game_state.gd`. The documents explain them; if they differ, the code takes precedence.
- **Decisions taken when merging the source documents:** [Game design › Design decisions](en/game-design.md#design-decisions).
- The Spanish documents are the originals; if the two versions ever disagree, the Spanish one and the code take precedence.
