# Godot Game Architecture

How the `game/` code (Godot 4.7, GDScript) is organized in the submitted version. Rules and design figures are in the [design](../game-design.md) and the [overview](../overview.md); backend and phone connectivity are covered in [networking.md](networking.md).

## Principles

- **Data-driven:** events, their options and their figures live in [`game/Data/events.json`](../../../game/Data/events.json), and science terms in `game/Data/glossary.json`. Add or balance events by editing JSON rather than code. Global rules (game length, daily consumption, Earth-help recharge) are constants in `game_state.gd` and `turn_manager.gd`.
- **State machine:** each Sol follows fixed phases inside `TurnManager`, keeping rule logic out of scenes.
- **Godot is authoritative:** only Godot calculates consequences. Phones send choices; see the [core rule](../../../CLAUDE.md#regla-fundamental-no-romper-nunca).
- **Single responsibility:** only `Net` accesses the WebSocket, only `PhoneBridge` translates between the game and the phones, only `GameState` changes resources (`modify_stat`), and scenes only render, listen to signals and call `TurnManager`'s public API.

## Folders

All scripts live in a single flat folder, `game/Scripts/`:

```text
game/
  project.godot             autoloads and main scene (Scenes/Main.tscn)
  Data/
    events.json             16 events with their options and figures ({"version": 3, "events": [...]})
    glossary.json           18 Word Book terms ({"terms": {...}})
  Scenes/
    Main.tscn               root: scene changes with fades, music, NasaApi and Sfx
    Main_menu.tscn          menu, mode choice (solo / multiplayer) and lobby with QR
    Intro.tscn              paged mission intro
    Gameplay.tscn           contains MainUI.tscn
    MainUI.tscn             cockpit: Mars window, bars, event, crew, Word Book
    OptionsPanel.tscn       sound options
  Scripts/
    events.gd               Events autoload: signal bus
    game_state.gd           GameState autoload: resources, progress, conditions, delayed effects
    glossary_manager.gd     GlossaryManager autoload: Word Book
    event_manager.gd        EventManager autoload: loads events.json and selects each Sol's event
    turn_manager.gd         TurnManager autoload: Sol state machine, voting, Earth help, DONKI
    net.gd                  Net autoload: WebSocket backend connection (see networking.md)
    phone_bridge.gd         PhoneBridge autoload: controller views and choice validation
    delayed_effects_queue.gd  DelayedEffectsQueue (RefCounted): delayed-effects queue
    nasa_api.gd             NasaApi: Jezero image from NASA Image and Video Library
    ...                     UI scripts (see table below)
```

## Components

### Autoloads

In `project.godot` order:

| Autoload | Script | Responsibility |
|---|---|---|
| `Events` | `events.gd` | Signal bus: scene changes, sound (`sfx_requested`) and network signals emitted by `Net` (`room_created`, `lobby_updated`, `game_started`, `player_choice_received`, `room_closed`…). |
| `GameState` | `game_state.gd` | Bars (0–100, starting at 80), current Sol, objective progress, crew away (`crew_away`), multi-Sol conditions (`active_conditions`), delayed-effects queue (`delayed_queue`), unlocked terms and Earth-help recharge. Applies option outcomes (`apply_outcome`, `apply_failure`), checks for the end (`check_end`) and computes the score. **The only place that modifies resources.** Signals: `stats_changed`, `progress_changed`, `conditions_changed`, `crew_changed`, `seismic_alert_activated`. |
| `GlossaryManager` | `glossary_manager.gd` | Loads `glossary.json` and unlocks terms (stored in `GameState.unlocked_terms`). Signal `term_unlocked`. |
| `EventManager` | `event_manager.gd` | Loads `events.json` into an `id → event` dictionary, filters by `conditions` and `cooldown_sols`, keeps scheduled events (`schedule_event`) and selects the Sol's event (`pick_event`). |
| `TurnManager` | `turn_manager.gd` | Sol state machine, reading time, countdown for critical events, phone voting and tie-break, busy crew, Earth help, waiting events and the DONKI query. The UI only calls `start_game()`, `submit_choice()`, `request_earth_help()`, `continue_after_resolution()` and `simulate_solar_flare()` (debug button). |
| `Net` | `net.gd` | The only code that touches the WebSocket: create room, send views and results, close. Emits network signals on `Events`. See [networking.md](networking.md). |
| `PhoneBridge` | `phone_bridge.gd` | Connects `TurnManager` to the phones through `Net`: decides each role's `controller_view`, validates each `choose` (current event, player, option, duplicates, `actionId` idempotency) and passes it to `TurnManager.cast_vote()`. Without an open room the game runs on a single screen. |

### Other scripts

| Script | What it is |
|---|---|
| `delayed_effects_queue.gd` | `DelayedEffectsQueue` (`RefCounted`): `{due_sol, outcome}` entries; `pop_due(sol)` returns the ones that are due. |
| `nasa_api.gd` | `NasaApi` (`HTTPRequest` node in `Main.tscn`): searches for and downloads a Jezero image from NASA Image and Video Library at startup; the intro shows it with its title. 3-second timeout; local image fallback. |
| `main.gd` | Root of `Main.tscn`: switches between menu, intro and gameplay with fades and changes the music. |
| `sfx.gd` | `Sfx` node in `Main.tscn`: plays the sounds requested through `Events.sfx_requested`. |
| `main_menu.gd`, `intro.gd`, `options_panel.gd` | Menu (solo or multiplayer, lobby with code and QR), intro and sound options. |
| `main_ui.gd` | Gameplay cockpit. Only displays state and forwards decisions to `TurnManager`; in solo play, options are chosen with the mouse. |
| `mars_view.gd`, `mars_landscape.gd` | Mars window: code-drawn landscape plus each event's `scene` block (image, framing and effect). |
| `crew_panel.gd`, `crew_avatar.gd` | The four crew helmets (grey when away from the base). |
| `glossary_view.gd` | Word Book inside the cockpit. |
| `earth_panel.gd`, `earth_help_face.gd` | "Ask Earth for help" window and button. |
| `end_screen.gd` | Victory or defeat screen with objectives and score. |
| `option_card.gd`, `option_info.gd` | Option card and cost texts (`OptionInfo.costs_text`, also sent to the controller as `detail`). |
| `event_button_face.gd`, `stat_icon.gd`, `ui_overlay.gd`, `menu_style.gd` | UI pieces: event button (exclamation mark if `important`), bar icons, modal window and button style. |
| `qr_code.gd` | `QrCode`: QR code generator in GDScript, with no external services. |

## Sol state machine

```gdscript
enum Phase { IDLE, SOL_START, EVENT_SELECTION, DECISION, RESOLUTION, SOL_END, ENDED }
```

| Phase | What happens |
|---|---|
| `IDLE` | Before `start_game()`. |
| `SOL_START` | Dawn: the Sol advances and automatic changes apply (see below). |
| `EVENT_SELECTION` | The Sol's event is selected. |
| `DECISION` | The event is shown. First there is a **reading time** (`reading`, 2.5–12 s depending on text length, at 23 characters per second) during which no choice is accepted; then players vote and, if the event has `timer_seconds`, the countdown starts. |
| `RESOLUTION` | The winning option is applied. The game waits for `continue_after_resolution()` (on-screen button or "continue" from the phones via `PhoneBridge`). |
| `SOL_END` | `GameState.check_end()`: defeat if any bar reaches 0; victory at the end of Sol `GameState.MAX_SOLS` (20); otherwise a new Sol begins. |
| `ENDED` | Game over: `game_ended` is emitted with the report (score, objectives, terms). |

What each phase means for players is in the [design](../game-design.md#sol-loop).

### Sol start

`TurnManager.start_game()` resets state, unlocks the `sol` term, queries DONKI **once** and begins Sol 1 without automatic changes. From Sol 2 on, `_begin_sol()` does, in this order:

1. `current_sol += 1`.
2. Crew members whose time away is over come back (`process_crew_return`).
3. Automatic bar changes (constants in `game_state.gd`):
   - Oxygen −3 (`PASSIVE_OXYGEN_LOSS`), only while MOXIE is below 100%.
   - Energy +7 (`PASSIVE_ENERGY_GAIN`); +6 from Sol 8 (`PASSIVE_ENERGY_GAIN_DUSTY`, `DUSTY_PANELS_FROM_SOL`).
   - Integrity −2 (`PASSIVE_INTEGRITY_LOSS`).
   - Health −4 from Sol 4 (`PASSIVE_HEALTH_LOSS`, `HEALTH_LOSS_FROM_SOL`).
4. Daily effect of each active condition, minus one Sol (`process_conditions`); its `on_end` applies when it ends.
5. Delayed effects due today (`process_delayed_effects`).
6. If the seismic network was just completed, `quake-warned` is scheduled in 1–2 Sols.
7. Defeat check (any bar ≤ 0).
8. If the whole crew is away (**empty base**), there is no event that Sol: a notice is shown and the day passes.
9. Event selection.

### Event selection

`TurnManager._select_event()` picks, in priority order:

1. The **solar alert** (`rt-solar-flare`) if DONKI returned an M- or X-class flare and it has not appeared yet.
2. A **waiting event** whose return Sol has arrived: an event for which Earth help was requested (it returns with its hint) or one postponed because nobody could choose any option.
3. `EventManager.pick_event()`:
   1. the first `auto` event whose conditions are met;
   2. a scheduled event due today (if its conditions still hold);
   3. an `objective` event (with probability 0.7 if random events are also available; weighted by `weight`), otherwise a `random` one;
   4. a `filler` event.

An event does not reappear until `cooldown_sols` Sols have passed (999, i.e. once, if not set). `scheduled_only` events appear only when another event schedules them.

When an event is shown for the first time it is marked as seen, its `terms` are unlocked and its `on_start` is applied. Each occurrence gets an identifier `"<id>#<n>"`, which is the protocol `eventId` (see [networking.md](networking.md#events-and-choices)).

### Decision and resolution

- **Blocked options:** an option with a `role` cannot be chosen while that crew member is away; a role-less option with `away_sols` (whole-crew outing) needs the whole crew at the base. If no option is possible, the event waits until someone comes back.
- **Who votes:** every player sees and can vote for **every** option (including other roles' options). Voters are roles with a connected phone, at the base and with at least one available option (`voters()`). Choices arrive via `Net` → `PhoneBridge` → `cast_vote()`; no effects apply when they arrive, only on resolution.
- **Vote resolution** (`_try_resolve_votes`): once everyone has voted, the most-voted option wins. On a tie, players vote again **among the tied options only** with a new `eventId` (`"<id>#<n>-tie"`). If it ties again, the **Commander's** vote decides (the first player to join the room; the backend marks them with `commander`); if the Commander voted for none of the tied options, the first one in event order wins.
- **Countdown:** when `timer_seconds` runs out, the most-voted option so far wins (on a tie, `timeout_option` if it is among the tied ones). With no votes, `timeout_option` is chosen or, if blocked, the first available option.
- **Single-screen play:** without phones, `main_ui.gd` calls `submit_choice()` directly.
- **Success or failure** (`submit_choice`): a roll against `success_chance` (1.0 if not set). On success, `feedback` is shown and the outcome (`apply_outcome`) and its `schedule_event` are applied. On failure, `fail_feedback` is shown, only the costs (negative effects) are paid, gains, progress and delayed effects are lost, and `on_fail` is applied; if the event has `retry_on_fail`, it can appear again. Either way, `away_sols` keeps the option's role (or the whole crew) busy.

### Earth help

`can_request_earth_help()` requires the decision phase (after reading time), a recharged Earth help, no active condition with `blocks_earth_help`, and an event that has `earth_hint` and is not `realtime`, `auto` or timed.

The ways to ask are in `TurnManager.EARTH_HELP_OPTIONS`:

| `id` | Cost | Reply |
|---|---|---|
| `full-report` | −5 Energy | in 1 Sol |
| `quick-message` | free | in 2 Sols |

When requested, the current event waits and the Sol ends. When the reply arrives, the event reappears with its `earth_hint` as a hint. Earth help recharges after `GameState.EARTH_HELP_COOLDOWN_SOLS` = 4 Sols, counted from the Sol it was requested.

### Solar alert (DONKI)

`start_game()` queries `DONKI/FLR` once (flares from the last 3 days, 3-second timeout). If there is an M- or X-class flare, the `realtime` event `rt-solar-flare` appears at the next event selection, with the real data appended to its description. If the query fails, there is no alert. The `simulate_solar_flare()` debug button triggers it immediately and interrupts the current event, which resumes afterwards.

## `events.json` format

```json
{
  "version": 3,
  "events": [ { "id": "greenhouse-dilemma", "kind": "random", "options": [ ... ] } ]
}
```

Events and options are plain **dictionaries** as parsed from JSON; there are no model classes. The full catalog is in the [event catalog](../event-catalog.md).

### Event fields

| Field | Type | Purpose |
|---|---|---|
| `id` | String | Event template. Each occurrence gets its own `eventId` (`"<id>#<n>"`). |
| `kind` | `random` · `objective` · `filler` · `auto` · `realtime` | Type; sets selection priority. |
| `title`, `description` | String | Screen text. The length of `description` sets the reading time. |
| `nasa_fact` | String | Real NASA fact shown with the event. |
| `terms` | Array of IDs | Glossary terms unlocked when the event appears. |
| `conditions` | Object · `null` | When it can appear (see below). |
| `cooldown_sols` | int | Sols before it can repeat (999 by default: once). |
| `weight` | number | Weight when choosing among `objective` events (1 by default). |
| `scheduled_only` | bool | Appears only if another event schedules it. |
| `important` | bool | The UI marks the event button with an exclamation mark. |
| `timer_seconds`, `timeout_option` | int, String | Countdown for critical events and default option when it ends. |
| `on_start` | outcome | Applied when the event is shown. |
| `earth_hint` | String | Hint brought by Earth's reply; without it Earth help cannot be requested. |
| `retry_on_fail` | bool | If the chosen option fails, the event can appear again. |
| `scene` | `{image, pan, effect, intensity}` | Mars window image (`effect`: `none`, `dust`, `flare`, `quake`, `dark`, `green`, `cool`). |
| `options` | Array | See below. |

### Conditions

All optional, combined with AND (`EventManager.conditions_met`):

| Key | Met when… |
|---|---|
| `min_sol`, `max_sol` | the current Sol is within that range. |
| `state` `{prop: value}` | `GameState.prop == value`. |
| `state_gt`, `state_lt` `{prop: n}` | `GameState.prop > n` / `< n`. |
| `any_of` `[condition, …]` | at least one is met. |

### Option fields

| Field | Type | Purpose |
|---|---|---|
| `id`, `label` | String | `id` is the protocol `optionId`. |
| `role` | String · `null` | Role that performs the task (`engineer`, `biologist`, `doctor`, `generalist`) or `null` for everyone. Anyone can vote for it. |
| `success_chance` | 0–1 | Probability of success. |
| `feedback`, `fail_feedback` | String | Text on success / on failure. |
| `effects` | `{bar: number}` | Immediate changes to `health`, `oxygen`, `energy`, `integrity`. |
| `set`, `add` | `{prop: value}` | Set or add to a `GameState` progress property (`SETTABLE` allow-list). |
| `chance` | `[{probability, effects, text}]` | Extra random effects. |
| `delayed` | `[{after_sols, …}]` | Outcome applied after `after_sols` Sols (`effects`, `set`, `add`, `text`, `away_all`). |
| `start_condition` | `{id, name, sols, daily \| sequence, blocks_earth_help?, on_end?}` | Starts a problem lasting several Sols. |
| `schedule_event` | `{id, min_sols, max_sols}` | Schedules another event. |
| `on_fail` | outcome | Extra penalty if the option fails. |
| `away_sols` | int | Sols the option's role stays busy (or the whole crew if `role` is `null`). |

An **outcome** is a dictionary with any of the keys `effects`, `set`, `add`, `chance`, `delayed`, `start_condition` (plus `away_all` in delayed entries); `GameState.apply_outcome()` applies it. Writable properties are `sensors_fabricated`, `sensors_placed`, `moxie_progress`, `rover_rescued`, `quake_happened`, `e2_pending` and `harvests_completed`.

## Runtime state

Everything is dictionaries and arrays inside the autoloads:

| Where | Shape |
|---|---|
| `GameState.active_conditions` | `[{id, name, sols, sols_left, step, daily \| sequence, blocks_earth_help?, on_end?}]` |
| `GameState.delayed_queue` | `DelayedEffectsQueue` with `[{due_sol, outcome}]` |
| `GameState.crew_away` | `{role: Sol they return}` |
| `EventManager._scheduled` | `[{id, due_sol}]` |
| `TurnManager._paused_events` | `[{event, return_sol, hint, fresh?}]` (Earth help or postponed event) |
| `TurnManager._votes` | `{role: optionId}` |

Objectives (`GameState.objectives_status()`): health always above 50, 3 harvests, rescue the rover, 3 sensors placed (the seismic alert only activates before Sol `SEISMIC_DEADLINE_SOL` = 13) and MOXIE at 100%. Score: 200 per objective plus the average of the four bars.

## Word Book (`glossary.json`)

`{"terms": {"<id>": {"title", "definition", "nasa_fact"}}}`, with 18 terms. They are unlocked through each event's `terms` field (plus `sol` at the start and `minutos_luz` when asking Earth for help). Each term's picture is `res://Images/Glossary/<id>.png`.

## Astronauts and skills (dropped)

The original class document proposed an `AstronautData` per player with individual health and a **skill per area** that changed success chance and cost (Expert 95% and ×0.5; Normal 75% and ×1; Novice 45% and ×1.5). This was dropped (see [design decisions](../game-design.md#design-decisions)): health is shared and each `events.json` option has its own `role` and `success_chance`.

## Changes from the original class design

The class document proposed `RefCounted` models (`MissionEvent`, `EventOption`, `MissionObjective`, `EarthTransmission`, `ActiveConditions`) built from JSON. The submitted version simplifies this to **JSON dictionaries + managers (autoloads)**:

| Earlier proposal (class PDF) | Now | Reason |
|---|---|---|
| Model classes `MissionEvent`, `EventOption`, `MissionObjective` | `events.json` dictionaries; objectives as `GameState` properties | Less code to maintain; JSON is the single definition. |
| `ActiveConditions` and `EarthTransmission` | `GameState.active_conditions` and `TurnManager` waiting events with `earth_hint` | Same behavior without extra classes. |
| `WebSocketBridge` with `JOIN_ROLE`, `SUBMIT_EVENT_CHOICE` and `ws://localhost:8000/ws/godot` | `Net` and `PhoneBridge` autoloads with the [contract](../protocol.md) messages on `/ws` | That protocol does not exist in the backend. See [networking.md](networking.md). |
| Role enum `ENGINEER, BIOLOGIST, MEDIC, COMMANDER` | Strings `engineer`, `biologist`, `doctor`, `generalist`; Commander as an extra capability of the first player | Contract and `events.json` IDs. |
| Fixed crew of 4 astronauts | Players from `game_started` (1–4); everyone votes on every option | Fewer than four can play. |
| `required_role`, `next_sol_effects`, `objective_progress` | `role`, `delayed`, `set` / `add` | `events.json` field names. |
| `MAX_SOLS = 15` | `GameState.MAX_SOLS = 20` | Length of the submitted version. |
| Earth-help reward catalog (`EARTH_CATALOG`) | `EARTH_HELP_OPTIONS`: the event waits and returns with a hint (`earth_hint`) | Help is a hint, not a resource reward. |

The original full class document remains in Git history (`docs/Clases Godot.pdf`).
