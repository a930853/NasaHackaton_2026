# Documentation (English)

## What to read

| If you want to… | Read |
|---|---|
| Understand the game or design events | [Game design](game-design.md) → [Event catalog](event-catalog.md) |
| Implement game logic in Godot | [Godot architecture](godot/architecture.md) |
| Connect Godot to phones | [Protocol](protocol.md) → [Godot networking](godot/networking.md) |
| Work on the web controller | [Protocol](protocol.md) → [Controller](controller.md) |
| Work on the backend | [Protocol](protocol.md) → [Backend](backend.md) |
| Deploy with Docker | [Deployment](deploy.md) |
| Get a summary of the implemented game | [Project overview](overview.md) |

## Documents

```text
docs/en/
  protocol.md          Message contract between Godot, controllers and backend. Network source of truth.
  backend.md           Node server: structure, room model, reconnection and message logging
  controller.md        Web controller (Vue): role/NFC routes, states, session recovery and styling
  deploy.md            Coolify Internet deployment and local Docker deployment
  game-design.md       Rules: Sol loop, roles, resources, objectives, APIs and open decisions
  event-catalog.md     Event catalog, options, effects and NASA sources
  crew-availability.md Crew availability and task durations
  overview.md          Summary of the implemented game
  godot/
    architecture.md    Managers, state machine, models and events.json format
    networking.md      Net autoload, rooms, lobby, QR, views and choice validation
```

## Sources of truth

- **Network messages:** [protocol.md](protocol.md). Agree on any change there first.
- **Event figures and numerical rules:** [`game/Data/events.json`](../../game/Data/events.json). The `game-design.md` and `event-catalog.md` explain them; if they differ, the JSON takes precedence.
- **Unresolved design choices:** [game-design.md — Open decisions](game-design.md#open-decisions).
- Spanish originals are in [`docs/`](../README.md).
