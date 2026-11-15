# Godot Game Architecture

How to organize `game/` code to implement the [design](../game-design.md). Backend and phone connectivity are covered in [networking.md](networking.md).

## Principles

- **Data-driven:** events, objectives and rules live in [`game/Data/events.json`](../../../game/Data/events.json). Add or balance events by editing JSON rather than code.
- **State machine:** each Sol follows fixed phases, keeping logic out of scenes.
- **Godot is authoritative:** only Godot calculates consequences. Phones send choices; see the [core rule](../../../CLAUDE.md#regla-fundamental-no-romper-nunca).
- **Single responsibility:** only `Net` accesses the WebSocket, only `GameState` changes resources, and scenes only render and listen to signals.

## Folders

Suggested layout within `game/`:

```text
game/
  Data/events.json          events, objectives and rules
  Scripts/
    events.gd               Events autoload: signal bus (exists)
    nasa_api.gd             NASA Image and Video Library query for the intro image
    net.gd                  Net autoload: WebSocket backend connection (see networking.md)
    autoload/
      game_state.gd         resources, objectives, current Sol, active conditions
      event_manager.gd      loads events.json and selects each Sol's event
      turn_manager.gd       Sol state machine
      glossary.gd           Glossary
    models/
      mission_event.gd      MissionEvent (one events.json entry)
      event_option.gd       EventOption (one option)
      mission_objective.gd  MissionObjective
      earth_transmission.gd EarthTransmission (Earth help in transit)
  Scenes/                   screens (render and listen to signals only)
```

## Components

| Component | Responsibility | Notes |
|---|---|---|
| `Events` autoload | Signal bus between systems and scenes. | Exists at `game/Scripts/events.gd`. |
| `GameState` autoload | Resources (0–100), objectives, current Sol, pending events, `active_conditions`, delayed effects and Earth-help cooldown. **The only place that modifies resources.** | Emits `stats_updated`. |
| `EventManager` | Loads `events.json`, filters events by `condition` and selects one. Unlocks glossary terms. | |
| `TurnManager` | Sol state machine; decides when to open, resolve and advance. | |
| `ActiveConditions` | Multi-Sol events (storms, deferred events) and their daily penalties. | May be part of `GameState`. |
| `DelayedEffectsQueue` | Effects scheduled for a future Sol (crops, Earth replies). | May be part of `GameState`. |
| `GlossaryManager` | Science terms: title, simple definition and NASA fact. Stores unlocked terms. | At least 10 terms initially. |
| `NasaApi` (`game/Scripts/nasa_api.gd`) | Searches for and downloads a Jezero image from NASA Image and Video Library at startup; the intro displays the image and title. | 3-second timeout; local image fallback. |
| `TurnManager` (`game/Scripts/turn_manager.gd`) | Queries DONKI `/DONKI/FLR` when a game starts to detect M/X flares from the previous three days. | 3-second timeout; no alert on failure, with a debug trigger available. |
| `Net` | Room, lobby, controller views and choices. | See [networking.md](networking.md). |

## Sol state machine

```gdscript
enum Phase { SOL_START, EVENT_SELECTION, DECISION, RESOLUTION, SOL_END }
```

See the [design](../game-design.md#sol-loop) for each phase. The order at **Sol start** matters:

1. Passive consumption: Energy −5 and Oxygen −5 (Oxygen only until MOXIE is complete). *The Energy −5 appears only in class code; confirm it.*
2. Apply delayed effects due today.
3. Apply each `active_conditions` daily penalty and decrement its remaining Sols.
4. Advance Earth transmissions; apply the reward when one reaches zero.
5. Reset “Earth help used today”.
6. Check for defeat (any resource ≤ 0).
7. Query the solar alert.

During **decision**, choices arrive via `Net`. `TurnManager` does not apply effects when receiving them; effects apply only during **resolution**.

## `events.json` format

```json
{
  "version": 1,
  "rules": { "max_sols": 30, "passive_oxygen_loss": 5, "max_pending_events": 2, "bars": ["energy", "oxygen", "integrity", "health"] },
  "objectives": { "sensors": { "...": "..." }, "moxie": { "...": "..." } },
  "earth_help": { "max_requests_per_sol": 1, "delay_sols_min": 2, "delay_sols_max": 3, "mode": "discard_option" },
  "events": [ { "id": "solar-storm", "...": "..." } ]
}
```

### Event fields

| Field | Type | Purpose |
|---|---|---|
| `id` | String | Event template. Protocol `eventId` identifies **one occurrence** (e.g. `solar-storm#1`); see [networking.md](networking.md#eventid-identifies-an-occurrence). |
| `category` | `"random"` · `"objective"` | Random event or part of an objective chain. |
| `objective` | String | Objective ID (`sensors`, `moxie`). |
| `title`, `description` | String | Screen text. |
| `nasa_source`, `real_fact` | String · null | Source and real-world fact. |
| `mode` | `"vote"` | Decision method. |
| `condition` | Object · null | Eligibility: `min_sol`, `max_sol`, `or_pending`, `requires_done`, `requires_not`, `triggered_by`, `objective_active`, `objective_progress`, `sensors_placed_before_sol`. |
| `persistent`, `decay`, `on_decay_end` | — | Event that penalizes each Sol until resolved; `decay` lists per-Sol effects. |
| `earth_discard` | String | Option discarded by Earth help. |
| `options` | Array | See below. |

### Option fields

| Field | Type | Purpose |
|---|---|---|
| `id`, `label` | String | `id` is the protocol `optionId`. |
| `role` | String · null | `null` = general vote; otherwise role (`engineer`, `biologist`, `doctor`, `generalist`). |
| `nfc_tool` | String · null | NFC tag that activates the option. |
| `effects` | `{ resource: number }` | Immediate effects. |
| `delayed_effects` | `[{ after_sols, effects, progress? }]` | Effects on future Sols. |
| `chance_effects` | `[{ probability, effects, feedback }]` | Random effects. |
| `progress` | `{ key: number }` | Objective progress (`moxie`, `sensors_fabricated`, `sensors_placed`). |
| `defer` | Boolean | Postpone: event remains pending and applies its `decay`. |
| `triggers_event`, `reopen_event`, `unlocks` | — | Chain events or change rules (e.g. `passive_oxygen_loss: 0`). |
| `feedback` | String | Outcome text. |

## Data models

Lightweight `RefCounted` classes are constructed from JSON and use the same field names as `events.json`.

```gdscript
class_name EventOption
extends RefCounted

var id: String
var label: String
var role: String
var nfc_tool: String
var effects: Dictionary
var delayed_effects: Array
var chance_effects: Array
var progress: Dictionary
var feedback: String
```

`MissionEvent` holds event metadata, conditions and `Array[EventOption]`. Its `available_options(present_roles)` method includes general options and options whose roles are present. `MissionObjective.add_progress(amount)` returns true only on the turn it completes; `fail()` marks it failed unless already complete. `EarthTransmission` stores `event_id`, remaining Sols, discarded option and arrival message.

## Astronauts and skills (undecided)

The original class document proposed `AstronautData` per player with individual health and skill by area:

| Skill | Success chance | Cost |
|---|---:|---:|
| 3 · Expert | 95% | ×0.5 |
| 2 · Normal | 75% | ×1 |
| 1 · Novice | 45% | ×1.5 |

`events.json` has no areas or role probabilities, and health is shared. See [open decisions](../game-design.md#open-decisions). If approved, add event `category` and a skill table to `rules`.

## Changes from the original class design

| Earlier proposal (class PDF) | Current direction | Reason |
|---|---|---|
| `WebSocketBridge` with `JOIN_ROLE`, `SUBMIT_EVENT_CHOICE` and `ws://localhost:8000/ws/godot` | `Net` autoload, contract messages (`create_room`, `choose`, `controller_view`…) on `/ws` | That protocol does not exist in the backend. See [networking.md](networking.md). |
| Role enum `ENGINEER, BIOLOGIST, MEDIC, COMMANDER` | Strings `engineer`, `biologist`, `doctor`, `generalist` | Contract and `events.json` IDs. |
| Fixed crew of 4 astronauts | Players from `game_started` (1–4) | Fewer than four can play. |
| `required_role`, `next_sol_effects`, `objective_progress` | `role`, `delayed_effects`, `progress` | `events.json` field names. |
| `MAX_SOLS = 15` in code | `rules.max_sols` | Rule belongs in data. |
| Earth-help reward catalog | `earth_help` in `events.json`: discard an option | Still under discussion. |

The original full class document remains in Git history (`docs/Clases Godot.pdf`).
