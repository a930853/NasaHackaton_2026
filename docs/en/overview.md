# Project Overview: Red Planet Survivors

Summary of what is **currently implemented**: game behavior, event types and data sources. Figures come from [`game/Data/events.json`](../../game/Data/events.json) and code in `game/Scripts/`; code takes precedence if it differs from this document.

> More detail: [game rules](game-design.md), [Godot networking](godot/networking.md), [message protocol](protocol.md) and [deployment](deploy.md).

## What it is

A cooperative educational NASA Hackathon 2026 game for **children aged 7–12** (simple English text). The crew has landed near Jezero Crater and must **survive 20 Sols** (Martian days) at a base, resolving one problem each Sol. Each problem is based on a real NASA mission or fact.

- **Main screen (Godot exported to web):** spacecraft cabin, Mars window, event information, four resource bars and crew.
- **Phones (web controller):** players join with a room code, choose roles and vote.
- **1–4 players**, or one person playing with a mouse.

## Project components

| Component | Folder | Responsibility |
|---|---|---|
| Game | `game/` (Godot 4.7, GDScript) | **Game authority:** events, rules, resources, choice validation and resolution. |
| Backend | `backend/` (Node, `express` + `ws`) | **Session authority:** rooms, players, roles and message forwarding over `/ws`. |
| Controller | `controller/` (Vue 3 + Vite + Tailwind) | Phone UI. Sends only the selected option; calculates nothing. |
| Landing | `landing/` | `/`: create a game or join with a code. |
| Deployment | `deploy/`, `compose.yaml` | Nginx with HTTPS serves the app through Docker Compose. |

Godot autoloads divide game logic:

| Autoload | Responsibility |
|---|---|
| `GameState` | Resources, objectives, current Sol, busy crew, active problems and delayed effects; only resource mutator. |
| `EventManager` | Loads `events.json`, checks conditions and cooldowns, selects each Sol's event. |
| `TurnManager` | Sol state machine, reading, voting, countdown, Earth help and solar alert. |
| `GlossaryManager` | Word Book (`glossary.json`). |
| `Net` | WebSocket connection to backend. |
| `PhoneBridge` | Sends views and validates incoming votes. |
| `Events` | Signal bus between systems. |

## How to play

**Start Game** offers:

- **Play solo:** one person, one screen. Options appear below the event and are selected with a mouse; no networking.
- **Play multiplayer:** create a room; phones join with the code, choose roles and vote. If the server does not respond within 4 seconds, offer solo play.

### Sol loop and resources

```text
SOL START ─► EVENT SELECTION ─► DECISION ─► RESOLUTION ─► SOL END ─► (next Sol or ending)
```

At dawn, crew members whose tasks are complete return. Automatic bar changes are Oxygen −3 until MOXIE is complete, Energy +7 (+6 from Sol 8 due to dust), Integrity −2 and, from Sol 4, Health −4. Apply active conditions and today's delayed effects. Select one event, read it, choose/vote, resolve and check for defeat or victory. Any resource at 0 means defeat; victory is reaching Sol 20 in the implemented version.

All bars start at 80 and range from 0 to 100. Roles: `engineer` (yellow; hardware, panels, rover, sensors, MOXIE, shields), `biologist` (green; greenhouse and probiotics), `doctor` (red; medicine and memory games), and `generalist` (white; shown as Generalist on screen and phones, called the Commander in some outcome texts).

### Objectives and scoring

Objectives include healthy crew (Health always above 50), stable colony (3 harvests), rover rescue, seismic network (3 sensors; early completion warns of quake) and MOXIE (100%, stopping Oxygen loss). Victory requires all resources above zero until the final Sol. Score is 200 per completed objective plus the average of the four bars.

## Event selection and resolution

`events.json` `kind` categories:

| Kind | Count | Selection |
|---|---:|---|
| Random (`random`) | 5 | Any Sol when conditions and cooldown allow. |
| Objective (`objective`) | 8 | Chains; prioritized over random events. MOXIE events have double selection weight. |
| Filler (`filler`) | 1 | Only if no other event is available. |
| Automatic (`auto`) | 1 | As soon as its condition is met, before other events. |
| Real-time (`realtime`) | 1 | Once per game for a recent strong NASA solar flare. |

Selection priority: pending solar alert; due waiting event (Earth reply or waiting for crew); eligible automatic event; previously scheduled event; objective or random event (70% objective when available); filler.

An event appears with a themed Mars-window effect. Its description types at 23 characters/second (2.5–12 seconds); until finished, players cannot choose, vote or ask Earth. NASA fact and options then appear. Solo mode uses mouse selection; multiplayer shows **all** options to connected players at base. A vote tie triggers another vote among tied options; if tied again, the Commander's vote (the first player who joined) decides. Quakes have a 20-second timer starting after reading. Resolution rolls `success_chance`: costs apply even on failure, rewards are lost, and `on_fail` may add a penalty; `retry_on_fail` can reopen the event. Role tasks may occupy crew for 0–2 Sols (`away_sols`); group tasks occupy everyone (`away_all`). If all are away, no event occurs that Sol.

Other `events.json` mechanics include immediate (`effects`) and delayed (`delayed`) effects, persistent conditions (`start_condition`), chance outcomes (`chance`), objective state (`set`, `add`), failures (`on_fail`), retries, scheduling (`schedule_event`), spawn effects (`on_start`), timers (`timer_seconds`, `timeout_option`), availability (`away_sols`, `away_all`) and selection weight (`weight`).

## Event families

- **Random:** Greenhouse Problem, Space Tummy Ache, Space Blues, Rover in the Sand, Dust on the Solar Panels.
- **Filler:** A Calm Sol.
- **InSight objective:** build sensors, place sensors, repair a dusty sensor, warned/unwarned Marsquake.
- **MOXIE objective:** assembly phases 1–3 and automatic MOXIE completion.
- **Real-time:** Solar Storm Alert from NASA DONKI (M/X class flare in the last three days); provides date/class and has a debug trigger.
- **Earth help:** pauses the event, returning it with Mission Control's `earth_hint` after 1 Sol for a full Commander report or 2 Sols for a quick message. Radio cooldown is 4 Sols. Unavailable during reading, quakes, solar alerts, MOXIE completion and an active solar-alert period.

The full list of delivered events, with their figures, is in the Spanish [resumen §6](../es/resumen.md#6-catálogo-de-eventos) and in [`events.json`](../../game/Data/events.json). The English [event catalog](event-catalog.md) is the original design, with NASA sources for each event.

## Word Book and data sources

The game glossary has 18 terms in `game/Data/glossary.json`, each with title, simple definition and NASA fact. Terms unlock when related events appear and can be reviewed using WORD BOOK without pausing.

| API | Use | Offline fallback |
|---|---|---|
| NASA DONKI (`/DONKI/FLR`) — `game/Scripts/turn_manager.gd` | At game start, checks the previous three days for M/X solar flares and triggers Solar Storm Alert with the real class/date | No live alert; a debug button can simulate one |
| NASA Image and Video Library — requested by `game/Scripts/nasa_api.gd`, displayed in `game/Scripts/intro.gd` | Loads a Jezero image and title for the intro background/credit | Local ESA Mars Express image |

These are the only NASA APIs currently queried. Requests originate in Godot, use a 3-second timeout, and the LAN demo works without Internet access. DONKI uses `DEMO_KEY` (low quota); the image library needs no API key.

JPL Horizons (Earth–Mars distance), Mars Rover Photos, and InSight Weather/MEDA are design ideas only and are not currently queried. Earth-help distance uses fixed values; rover imagery is local, and live weather adds no bonus.
