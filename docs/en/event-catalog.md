# Event Catalog (original design)

> **This is the catalog the game was designed from.** Figures, conditions and some events were tuned during development (for example, the solar storm became a real-time event driven by NASA DONKI data). For the event families and rules of the **submitted version**, see the [project overview](overview.md); the exact figures are in [`game/Data/events.json`](../../game/Data/events.json).

The game's event catalog. General rules (voting, roles and Earth help) are in [game-design.md](game-design.md).

- **The figures below are the original design.** Current values are in [`game/Data/events.json`](../../game/Data/events.json); where they differ, the JSON wins.
- **Who:** “Everyone” means a general vote; a role means only that role may choose (and the option appears only when the role is present).
- **Sol+N:** effect applies N Sols later.
- Each event includes its original-design ID. Some changed or were dropped in `events.json` (for example, `sensor-failure` is now `sensor-dust`, and `solar-storm` does not exist: `rt-solar-flare` replaces it).
- **Commander (`generalist`):** in the original design the `generalist` role was called Commander. In the submitted version that role is the Generalist, and the Commander is the first player to join (see [game-design.md](game-design.md)).

## Random events

### Solar Radiation Storm — `solar-storm`
Not in the submitted version; see [Real-time solar alert](#real-time-solar-alert). **NASA source:** DONKI, coronal mass ejection (CME) as a design reference; the game does not query the CME endpoint.

> Sensors detect a CME approaching Mars. Protect the crew before the radiation arrives.

| Option | Who | Effects |
|---|---|---|
| Activate magnetic shields (`NFC_SHIELD`) | Everyone | Energy −20 |
| Redirect power from the labs | Engineer | Energy −5, Integrity −5 |
| Keep experiments running | Everyone | Energy +5, Integrity −20, Health −10 |

### The Greenhouse Dilemma — `greenhouse-dilemma`
**NASA source:** Curiosity mission, Gale Crater soil analysis (minerals and clays).

> Food rations are running low. The Biologist is growing “Martian” potatoes with probiotics in Gale Crater soil, but the sprouts are tiny. Eat now or wait?

| Option | Who | Effects |
|---|---|---|
| Eat the sprouts now | Everyone | Health +15, Oxygen −10; Sol+1: Oxygen −10 |
| Wait and ration food | Biologist | Health −10, Oxygen +10; Sol+2: Health +10 (harvest) |
| Use grow lights | Engineer | Energy −15, Oxygen +10, Health +10 |

### Space Tummy Ache — `space-bellies` (persistent)
**NASA source:** OSDR study on radiation and probiotics (`Lacticaseibacillus rhamnosus` GG), DOI 10.26030/y1ww-ep94.

> Radiation is upsetting the crew's stomachs. If not treated today, it gets worse; each unresolved Sol costs Health.

| Option | Who | Effects |
|---|---|---|
| Probiotic shakes | Biologist | Health +20, Energy −5, Oxygen −5 (uses plants) |
| Standard med kit (`NFC_MEDKIT`) | Doctor | Health +15, Integrity −5 |
| Postpone | Everyone | Energy +5; pending penalties: Health −5, −5 and −10 over the next three Sols, then it closes |

**Real fact:** NASA research found that *L. rhamnosus* GG can affect how the human gut responds to space radiation.

### Mental Fog and Isolation — `mental-fog`
**Condition:** from Sol 5 (Sol 4 in the submitted version), or earlier if “Space Tummy Ache” is pending. **NASA source:** OSDR research on spaceflight effects on the human brain (brain organoids), DOI 10.26030/twtb-sc40.

> After many Sols of red rocks, the crew is sad, distracted and arguing. Research on Earth has studied the effects of isolation and spaceflight on the brain.

| Option | Who | Effects |
|---|---|---|
| Video-game and music tournament | Commander (`generalist`) | Health +20, Energy −10 |
| Memory and relaxation exercises | Doctor | Health +15, Energy −5 |
| Ignore it and work quietly | Everyone | Health −10; Sol+1: Integrity −5 |

### Rover Stuck in the Sand — `rover-stuck`
**NASA source:** Curiosity landing area, Rocknest dunes. **Planned API only:** recent Perseverance photos; the game does not currently request these images.

> Your small exploration robot is stuck in a dune and has lost its signal. It has valuable data inside.

| Option | Who | Effects |
|---|---|---|
| Remote-control it from base | Engineer | Energy −10, Oxygen +15 (ice samples) |
| Go outside in suits to rescue it | Everyone | Oxygen −5, Health −10, Energy +10; 50% chance of +10 extra Energy (special rock) |
| Abandon it | Everyone | Energy +5, Integrity −10 (no rover to inspect outside) |

### Dust on the Panels — `dust-panels`
**NASA source:** Opportunity mission and Martian dust storms. **Planned API only:** InSight Weather/MEDA data; live wind does not currently grant Energy.

> A dust storm has covered the base's solar panels. They produce less electricity and batteries are dropping.

| Option | Who | Effects |
|---|---|---|
| Clean panels in suits | Everyone | Oxygen −15, Health −5, Energy +20 |
| Reprogram panels to shake | Engineer | Energy −10; Sol+1: Energy +15, Integrity +5 |
| Ration electricity | Everyone | Energy +10, Health −10, Integrity −5 (cold damages pipes) |

In the submitted version the third option is “wait for the storm to pass” (`wait-it-out`): Energy +5, Integrity −5, plus a dust storm that drains 10 Energy every morning for 2 Sols.

**Real fact:** Opportunity kept working for years because wind cleaned its panels. This crew cannot wait for the wind.

## Seismic sensor network objective (InSight)

Build and place three sensors. If placed before Sol 20, the quake is forecast one Sol in advance; otherwise it arrives without warning. In the submitted version the deadline is Sol 13 (`SEISMIC_DEADLINE_SOL`) and the warned quake arrives 1 or 2 Sols after the network is complete.

### S1. Build three sensors — `sensors-fabricate`

| Option | Who | Effects |
|---|---|---|
| 3D-print them | Engineer | Energy −25; 3 sensors built |
| Recycle parts from the old rover | Everyone | Integrity −10, Energy −5; 3 sensors built |
| Hold them together with duct tape | Everyone | Energy −10; 3 sensors built, but one will fail and trigger S3 within three Sols (1–2 Sols later in the submitted version) |

### S2. Place the three sensors — `sensors-place`

| Option | Who | Effects |
|---|---|---|
| One long EVA | Everyone | Energy −35, Oxygen −25; all 3 placed |
| Precision-tool EVA | Engineer | Energy −30, Oxygen −15; all 3 placed |
| Two trips on different Sols | Everyone | Energy −20, Oxygen −15; 2 placed; Sol+1: Energy −10, Oxygen −10, third sensor placed |

### S3. Sensor covered in dust — `sensor-failure` (`sensor-dust` in `events.json`)

Triggered by the duct-tape choice in S1.

| Option | Who | Effects |
|---|---|---|
| Go outside to repair it | Everyone | Energy −10, Oxygen −5 |
| Restart it remotely | Engineer | Energy −5 |
| Leave it and build another | Everyone | Lose 1 placed and built sensor; S1 reopens |

In the submitted version, leaving it only removes one placed sensor (`sensors_placed` −1): S1 does not reopen, and the missing sensor is placed again through S2.

### S4. Marsquake! — `quake-warned` / `quake-unwarned`
**Emergency: 20 seconds to choose.** InSight detected more than 1,300 quakes, up to magnitude 5.

**With warning** (`quake-warned`, complete network before Sol 20; before Sol 13 in the submitted version): reinforce the structure (Engineer: Energy −10, Integrity intact) or evacuate to the safe room (Everyone: Oxygen −5, Energy −5, Integrity intact).

**Without warning** (`quake-unwarned`, from Sol 8 if the network was not completed in time; from Sol 14 in the submitted version): repair the damage (Everyone: Integrity −20, Energy −10).

## MOXIE oxygen generator objective

MOXIE has three assembly phases (33 + 33 + 34%). At 100%, passive Oxygen loss per Sol stops (−3 per Sol in the submitted version, `PASSIVE_OXYGEN_LOSS` in `game_state.gd`).

### M1. First phase — `moxie-phase-1`

| Option | Who | Effects |
|---|---|---|
| Full-speed assembly | Everyone | Energy −25; MOXIE +33% |
| Careful assembly | Engineer | Energy −15; MOXIE +33% |
| Use greenhouse parts | Everyone | Energy −10, Oxygen −10; MOXIE +33% |

### M2. MOXIE vs. greenhouse — `moxie-phase-2`

| Option | Who | Effects |
|---|---|---|
| Prioritize MOXIE | Everyone | Energy −20, Health −5; MOXIE +33% |
| Share the schedule | Biologist | Energy −10; MOXIE +33% |
| Turn off lab and greenhouse for one Sol | Commander (`generalist`) | Energy −5, Health −10; MOXIE +33% |

### M3. Filter failure — `moxie-phase-3`

| Option | Who | Effects |
|---|---|---|
| Clean it by hand | Everyone | Energy −10, Oxygen −5; MOXIE +34% |
| Replace the filter | Engineer | Energy −15; MOXIE +34% |
| Ignore it | Everyone | MOXIE −33% (lose one phase) |

### M4. MOXIE works! — `moxie-done`

Automatically triggers at 100%; no choice. Celebrates success and **removes passive Oxygen consumption**.

## Special events

### Ask Earth for help

Not an event in `events.json`: its options are in `TurnManager.EARTH_HELP_OPTIONS` (`game/Scripts/turn_manager.gd`) and the wait between requests is `GameState.EARTH_HELP_COOLDOWN_SOLS`. Based on the 4–24-minute Earth–Mars communication delay and Mission Control operations. JPL Horizons distance lookup is planned, not currently used.

| Option | Who | Effects |
|---|---|---|
| Send the full report | Commander | Energy −5 (full-power antenna); faster reply |
| Send a quick message | Everyone | No cost; slower reply |
| Cancel and decide yourselves | Everyone | Return to normal event; cannot ask for help with it again this Sol |

Once per Sol in the original design. In the submitted version there are only two options (full report: Energy −5, reply in 1 Sol; quick message: free, reply in 2 Sols), help can be requested once every 4 Sols, and the reply brings the event's hint (`earth_hint`) (see [design decisions](game-design.md#design-decisions)).

### Real-time solar alert

**API:** DONKI `/DONKI/FLR` only. At game start, the game checks flares from the previous three days; a recent class M or X flare interrupts the turn and displays its real date. `/DONKI/CME` is not queried. Earth help is blocked during this Sol and the next.

| Option | Who | Effects |
|---|---|---|
| Probiotic shakes | Biologist | Oxygen −5, Health +5 |
| Shields | Engineer | Energy −10 |
| Hide in the middle room (`shelter`) | Everyone | Health −5, Energy −5 |

The general option `shelter` (`rt-solar-flare` in `events.json`) ensures the event can be resolved even when neither the Biologist nor the Engineer is present; see [roles](game-design.md#roles).
