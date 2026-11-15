# Game Design: Mars Survival

The rules defined by the team. The event catalog is in [event-catalog.md](event-catalog.md); implementation details for Godot are in [Godot architecture](godot/architecture.md).

> **Source of truth for numbers:** [`game/Data/events.json`](../../game/Data/events.json), which is loaded by the game. This document explains the rules; if a number differs, `events.json` takes precedence and this document should be corrected. Unresolved issues are listed under [Open decisions](#open-decisions).

## Concept

A cooperative educational game for **four players**, lasting about **30 minutes**. The crew lives at a Mars base near Jezero Crater and must survive a fixed number of Martian days (*Sols*) while completing scientific objectives. Every event is based on a real NASA mission or fact.

- **Main screen (Godot):** displays the event, base resources and outcome.
- **Phones:** each player has a role and chooses options. NFC tool tags on the table can also be used.
- The game supports **1–4 players**: no mandatory decision may depend on a role that is absent.

### Main-screen sketch

![Main screen sketch: window, button desk and information panel](../juego/img/prototipo-ui.png)

- **Window:** view of the world outside the base.
- **Button desk:** the four resources (health, oxygen, energy, integrity), **Decisions** and **Dictionary** (the [Glossary](#glossary)).
- **Information screen:** details about the selected button.

## Sol loop

Time advances **in turns**: one main event per Sol and no timer, so players can discuss. Only emergencies have a countdown (20 seconds).

```text
SOL START ──► EVENT SELECTION ──► DECISION ──► RESOLUTION ──► SOL END ──┐
     ▲                                                                  │
     └──────────────────── (if the game continues) ────────────────────┘
```

| Phase | What happens |
|---|---|
| **Sol start** | Advance the Sol counter. Automatic resource changes (see [Balancing](#difficulty-balance)): Oxygen −4 until MOXIE is complete, Energy +7 (+6 from Sol 8), Base Integrity −3 and, from Sol 4, Health −6. Apply persistent-event and scheduled effects due today. Query the space-weather API; a flare triggers the [real-time event](#real-time-solar-alert). |
| **Event selection** | Choose a valid event based on its conditions (objective chains or random events). Unlock its terms in the [Glossary](#glossary). |
| **Decision** | Show title, description, NASA fact and options. Players vote or the assigned role chooses. Players may [ask Earth for help](#ask-earth-for-help). |
| **Resolution** | Apply immediate effects, schedule delayed effects and show the outcome text. |
| **Sol end** | Check for defeat (any resource at 0) and victory (the final Sol). |

## Roles

| Role (code ID) | Display name | Specialties (based on events) |
|---|---|---|
| `engineer` | Engineer | Hardware, panels, rover, sensors and MOXIE; the most role-specific options. |
| `biologist` | Biologist | Greenhouse, crops and probiotics. |
| `doctor` | Doctor | Health, first aid and stress. |
| `generalist` | Generalist | Can take part in general decisions and tasks like any other role. |

The English IDs are used by the [message contract](protocol.md) and `events.json`. Event options are either:

- **General vote** (`role: null`): everyone present may vote.
- **Role option** (`role: "engineer"`…): only that role may choose it. It is **offered only if that role is in the game**. Each event has at least one general-vote option so play can always continue.

## Base resources

Four bars range from 0 to 100 and start at 80. **If any reaches 0, the game is lost.**

| Resource | ID | Notes |
|---|---|---|
| Energy | `energy` | Batteries and solar panels. Gains **+7 per Sol** (+6 from Sol 8, when dust covers the panels). |
| Oxygen | `oxygen` | Passively loses **4 per Sol** until MOXIE is complete. |
| Integrity | `integrity` | Condition of the base structure and equipment. |
| Health | `health` | Crew health. Extra goal: never drop below 50%. |

### Difficulty balance

Bars change not only because of player choices: each is under **automatic pressure at dawn**, so defeat is not caused by oxygen alone. Values are `GameState` constants (`PASSIVE_*`, `*_FROM_SOL`); MOXIE event weighting is configured by `weight` in `events.json` (MOXIE events have weight **2**, versus 1 when selecting between objectives).

| Bar | Change each Sol | Reason |
|---|---|---|
| Oxygen | −4 until MOXIE reaches 100% | Breathing; the game's race against time. |
| Energy | +7 (+6 from Sol 8) | Dust accumulates on solar panels. |
| Base Integrity | −3 | Wind and dust wear down the walls. |
| Health | −6 from Sol 4 | Stress and radiation; the crew starts rested. |

With the earlier rules (Oxygen −5 and no other automatic changes), an attentive player lost every game to oxygen: 95 points lost over 20 Sols against 80 starting points. Health and Integrity were never lethal.

The simulator `tools/balance_sim.py` repeats the game rules and can be run with `python tools/balance_sim.py`. It models an **attentive** player (checks costs and goals and protects the lowest bar) and a **random** player. A real person falls between them.

| Player | Wins | Oxygen losses | Energy losses | Health losses | Integrity losses |
|---|---:|---:|---:|---:|---:|
| Attentive, before | 41% | 59% | 0% | 0% | 0% |
| Attentive, current | 47% | 19% | 13% | 9% | 11% |
| Random, before | 6% | 94% | 0% | 0% | 0% |
| Random, current | 3% | 55% | 3% | 33% | 7% |

For an attentive player, losses are distributed fairly evenly; oxygen and health still dominate for random choices. MOXIE is completed in 82% of attentive games (previously 51%).

To adjust difficulty: increasing `PASSIVE_OXYGEN_LOSS` or lowering MOXIE's weight makes the game harder and shifts losses toward Oxygen; `PASSIVE_HEALTH_LOSS` and `HEALTH_LOSS_FROM_SOL` are very sensitive; lowering `PASSIVE_ENERGY_GAIN` pressures Energy. Re-run `tools/balance_sim.py` after changes (its `Cfg` class mirrors the constants).

## End screens; victory and defeat

The themed `EndScreen` (`game/Scripts/end_screen.gd`) shows a blue button frame, pixel-art title and rocket/Mars, four crew helmets, objective results, score and discovered words, plus *Play again* and *Back to menu* buttons.

- **Victory (“Mission complete!”):** gold title, upright rocket with a lit engine, glowing Mars, colorful helmets and confetti; `success` sound.
- **Defeat (“Mission failed!”):** gently pulsing red screen, fallen rocket by a dark Mars, gray helmets and the depleted resource icon; `failure` sound.
- **Defeat:** any resource reaches 0.
- **Victory:** survive through the last Sol (**30**, in `events.json`). Score depends on completed objectives.

## Objectives

| Objective | Requirement | Reward | In `events.json` |
|---|---|---|---|
| **Seismic sensor network** (InSight mission) | Build and place 3 sensors. | If placed before **Sol 20**, the quake is forecast one Sol ahead. | Yes (`sensors`) |
| **MOXIE oxygen generator** | Complete assembly phases to 100%. | Stops passive Oxygen loss. | Yes (`moxie`) |
| **Healthy crew** | Keep Health above 50% for the whole game. | Counts toward score. | No |
| **Stable colony** | Successfully grow 3 crops. | Counts toward score. | No |
| **Rover rescue** | Free the rover trapped in the dunes. Inspired by Spirit, trapped in soft sand in 2009. | Counts toward score. | No (only `rover-stuck`) |

## Event mechanics

| Mechanic | Example | `events.json` field |
|---|---|---|
| Immediate effects | Oxygen −10 | `effects` |
| Delayed effects | Eat sprouts: Oxygen −10 next Sol | `delayed_effects` |
| Persistent event | If postponed, Space Tummy Ache causes −5, −5 and −10 Health | `persistent`, `decay`, `defer` |
| Random chance | 50% chance of finding a special rock (+10 Energy) | `chance_effects` |
| Objective progress | MOXIE +33% | `progress` |
| Chained events | Duct-tape sensors trigger a later failure | `triggers_event`, `condition`, `reopen_event` |
| NFC tool | Activate an option with a tag | `nfc_tool` |

At most **2 events** can be pending at once (`max_pending_events`).

## Crew away from the base

Each option keeps its actor busy for 0, 1 or 2 Sols (`away_sols` in `events.json`). Durations by option are listed in [crew availability](crew-availability.md).

- A role-specific option occupies that astronaut for `away_sols` Sols. If it is 1 Sol, they are unavailable tomorrow and return the following day.
- A group option (“everyone” with `away_sols`) occupies the whole crew, leaving the base empty. It can only be chosen if all four are at the base. “Two walks” occupies nobody today but makes the whole crew busy tomorrow (`away_all` in the delayed effect).
- Busy astronauts cannot participate; their role options are disabled and their phone shows “You are busy!”.
- **Empty base:** if all four are busy at the start of a Sol, no event is generated. Normal daily consumption applies and a message explains that the day passes.
- Astronauts return on the specified Sol, announced at dawn with a door sound.
- The cabin's lower-right strip shows four helmets: colored and “READY” at base; gray and “BUSY - N Sols” while away.

## Event reading and presentation

The event description is typed out at 23 characters per second (2.5–12 seconds; current events take 3.3–8.6 seconds, about 5.8 seconds on average). Players cannot decide until it finishes: options appear after the text in solo mode; phones show “Read the story!” until then; Earth help is also unavailable. NASA facts and Earth's hint appear afterward. Critical-event countdowns (quakes) start **after** the reading. Constants are in `TurnManager` (`READING_CHARS_PER_SECOND`, `READING_MIN_SECONDS`, `READING_MAX_SECONDS`). A voting tie-break does not repeat the reading. `Texting_SFX` loops during reading and fades out when reading ends, the event resolves or the game ends.

The tutorial has six illustrated pages: welcome, the four bars and daily changes, reading/choosing/voting, jobs and busy crew, tools (Earth help, glossary and menu), and objectives. Content is in `intro.gd` (`PAGES`: title, BBCode text and images with `paths`, `caption`, `max` and `pixel`). Update text and screenshots when mechanics or UI change. Tutorial pages type at 55 characters per second (1.5–10 seconds); pressing *Next* while typing reveals the rest, and the next press advances.

Dawn updates (“the Engineer returned”, “Oxygen dropped by 4”…) no longer appear over the event: changes appear on the bars and in their history, while crew availability appears in the avatars.

## What appears where

| Location | Content |
|---|---|
| Godot's right-hand screen | Event title, description, NASA fact, Earth hint and decision result. In multiplayer, options are on phones; in solo mode, they appear below the event and are selected with the mouse. |
| Each player's phone | **All** event options, including those assigned to other roles. Role options show their role and costs; disabled options explain why. |

**MENU and Word Book.** The gray plate at the cabin's upper-right has a **MENU** button. It overlays the whole right screen (including Sol and objective headers) with **Options** (sound controls) and **Exit** (leave the game and return to the main menu; in multiplayer this also closes the room). A blue **X** or MENU closes the overlay. **WORD BOOK** shows discovered terms; new entries are highlighted with “NEW!”. Opening the menu does not pause the game, and a new event closes it.

**Start Game** offers **solo** (one screen, no phones or network; choose with the mouse) or **multiplayer** (lobby, phones and voting). In solo mode, `TurnManager.submit_choice` applies the choice directly without voting.

The `Phone (debug)` simulator is hidden: solo options are shown on screen, and multiplayer uses real phones (its code remains in `main_ui.gd`). Only `Flare (debug)` remains to simulate a solar alert. `TurnManager.controller_view_for(role)` prepares each controller view, and `submit_choice_from(role, eventId, optionId)` validates it. Options may include `detail`, `disabled` and `reason` as specified in `protocol.md`; real phones are handled by `PhoneBridge` (see [Godot networking](godot/networking.md)).

## Ask Earth for help

This mechanic is based on real communication delays: 4–24 minutes per message between Mars and Earth, depending on distance.

- Available for any unresolved event. The radio recharges every **4 Sols** (`GameState.EARTH_HELP_COOLDOWN_SOLS`), allowing at most five requests in a 20-Sol game. Four was chosen instead of three so it remains a valuable hint rather than a daily button.
- The event becomes **“Waiting for Earth”** and the reply arrives **2–3 Sols** later. Persistent events continue applying their penalties while waiting.
- According to `events.json`, the reply **removes a bad option** (`earth_discard` identifies it).
- Planned choices: **Send the full report** (Commander, −5 Energy, faster answer); **send a quick message** (general vote, free, slower answer); **cancel and decide yourselves** (cannot request help for that event again this Sol).
- JPL Horizons is a planned integration for showing the day's Earth–Mars distance and radio delay; it is not queried by the game yet. Current design fallback: 225 million km and 12 minutes.
- Earth help is unavailable during a solar alert.

## Real-time solar alert

- At the start of a game, query NASA DONKI for solar flares from the previous three days.
- An M- or X-class flare interrupts the turn with a special event showing the real date.
- During that Sol and the next, Earth help is unavailable and radiation increases. The crew can be protected with probiotics (Biologist) or shields (Engineer).
- A debug button should simulate a flare without relying on the API.

## Glossary

The educational glossary unlocks technical terms (Sol, MOXIE, Jezero Crater, regolith, coronal mass ejection, probiotics…) when their events appear. Players can view a simple definition and a NASA fact without pausing the game. New terms trigger a notification.

The Word Book displays one pixel-art tile per word (`game/Images/Glossary/<term-id>.png`, 32×32). Unknown words are dimmed with a “?”; unseen new words have an orange border. The details panel shows the illustration, title, explanation and NASA fact, with a discovered/total counter. Icons are generated by `tools/make_glossary_icons.py`; add a drawing there and regenerate icons when adding a term to `glossary.json`.

## NASA APIs

Only the following NASA APIs are queried by the current game. Requests run directly from Godot, not the web controller or Node backend; the demo remains playable offline.

| Active API | Where it is used | Purpose and offline fallback |
|---|---|---|
| [NASA DONKI](https://api.nasa.gov/) (`/DONKI/FLR`) | `game/Scripts/turn_manager.gd`, when a game starts | Checks flares from the previous three days. An M/X flare triggers Solar Storm Alert with its real class and date. Offline or on request failure, no live alert is triggered; the debug button can simulate one. Uses `DEMO_KEY` (low quota). |
| [NASA Image and Video Library](https://images-api.nasa.gov/search?q=jezero%20crater&media_type=image) | Requested by `game/Scripts/nasa_api.gd` at startup; displayed by `game/Scripts/intro.gd` | Loads a Jezero image and its title for the intro background and credit. If unavailable, the local ESA Mars Express image is used. |

Both requests use a 3-second timeout. The image library request does not require the DONKI API key.

### Planned NASA API integrations (not currently queried)

| API | Planned use | Current behavior |
|---|---|---|
| [JPL Horizons](https://ssd.jpl.nasa.gov/api/horizons.api) | Earth–Mars distance and radio delay for Earth help | Fixed design values: 225 million km and 12 minutes |
| [Mars Rover Photos](https://api.nasa.gov/) | Perseverance photos for the intro or rover event | Local art; no API request |
| InSight Weather / MEDA | Wind bonus in “Dust on the Solar Panels” | No bonus from live weather data |

## Open decisions

Contradictions arose while converting source PDFs to Markdown. Resolve each issue and update this document and `events.json`.

| Topic | Conflicting sources | Current `events.json` |
|---|---|---|
| Game length | 15 Sols (classes), 20 Sols (specifications), 30 Sols (events) | `max_sols: 30` |
| Additional ability | Commander; granted to the first player in addition to their primary role | `commander: true` |
| Health | One shared bar (specifications) or one per astronaut (classes) | One shared `health` bar |
| MOXIE phases | Four phases of 25% (events) or three of 33% (specifications) | Three phases (33 + 33 + 34) |
| Sensor deadline | Before Sol 20 (events) or Sol 13 (specifications) | Sol 20 |
| Earth-help reward | Reveal best option, give a hint or remove an option | Remove an option |
| Help delay | 2–3 Sols (events) or 1–2 (specifications) | 2–3 Sols |
| Role skill chance/cost | Expert 95%/×0.5; normal 75%/×1; novice 45%/×1.5 | Not implemented |
| Health, colony and rover objectives | Included in design | Only `sensors` and `moxie` exist |
| Victory condition | Complete at least 3 of 4 objectives (classes) or score by objectives | Not defined |
| Rover location | Jezero Crater or Rocknest dunes (Gale Crater) | Rocknest |

Sources compared: the “Godot Classes” PDF, “Events / Games” PDF, and former `docs/especificaciones.md`; their content is integrated into the design docs and originals remain in Git history.
