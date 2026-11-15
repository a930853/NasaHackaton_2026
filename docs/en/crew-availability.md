# Crew Availability and Task Durations

This document defines how long each character (Engineer, Biologist, Doctor and Generalist) takes to perform actions in a **20-Sol** game, and what happens when everyone is away from the base.

## 1. Occupation and an empty base

- **Task lock:** when a player chooses an option assigned to their role (or a group expedition), that character is marked **Busy / Away from base** for a specified number of Sols (`0`, `1` or `2`).
- **Unavailable for selection:** while a character is away (has an entry in `GameState.crew_away`, which stores the Sol they return), that character cannot be selected for role-specific options on later turns.
- **Empty-base rule:** at the start of a Sol, the game checks who is at the base. If **all four are busy (`GameState.base_is_empty()`)**, nobody is at the base to receive or handle problems: **no event is generated that day**, and normal daily consumption applies. The turn does not advance by itself: the screen shows “The base is empty!” in the resolution phase, with the Sol the crew returns, and waits for *Continue* (`TurnManager._empty_base_day()`).

## 2. Durations by role and task type

The game lasts **20 Sols**. Durations range from 0 to 2 Sols to keep the pace without blocking play for too long.

| Role | Instant task (`0 Sols`) | Standard task (`1 Sol`) | Expedition / long task (`2 Sols`) |
|---|---|---|---|
| **Generalist** (`generalist`) | Quick communications and reports to Earth. | Morale, emergency protocols and scheduling. | None; always supervises command. |
| **Doctor** | First aid and quick treatments. | Cognitive therapy, relaxation and in-depth medical follow-up. | None; remains in the infirmary. |
| **Biologist** | Biological processes take at least one Sol. | Probiotic shakes, rationing and light schedules. | Intensive crop growing and full laboratory cycles. |
| **Engineer** | Repairs take at least one Sol. | Remote console operations (telemetry, lights, panel vibration, 3D printing). | Long EVAs: placing seismic sensors or assembling heavy MOXIE phases. |
| **General vote** | Passive decisions, postponing problems or rationing resources inside the base. | **Group EVAs:** everyone leaves in suits (rover rescue, panel cleaning or group sensor placement). The base is empty the following Sol. | Not applicable. |

## 3. Durations by event

### General events

- **E1 (Greenhouse):** eat sprouts, 0 Sols; Biologist protects crops, 2 Sols busy; Engineer uses grow lights, 1 Sol busy.
- **E2 (Space Tummy Ache):** Biologist makes probiotic shakes, 1 Sol; Doctor uses the medicine kit, 0; general option postpones, 0.
- **E3 (Mental Fog; “The Space Blues” in the game):** Generalist holds a video-game tournament, 1 Sol; Doctor runs memory exercises, 1; general option ignores it, 0.
- **E4 (Rover Stuck):** Engineer remote-controls it, 1 Sol; group EVA rescue, 1 Sol for everyone (base empty next day); abandon it, 0.
- **E5 (Dust on Panels):** group EVA cleaning, 1 Sol for everyone (base empty next day); Engineer vibrates panels, 1; ration power, 0.

### Objective 1: InSight seismic sensors

- **S1 (Build sensors):** Engineer uses 3D printer, 1 Sol; everyone recycles rover parts, 1 Sol for the whole crew; general duct-tape option, 0.
- **S2 (Place all three):** group long EVA, 1 Sol for everyone (base empty next day); Engineer's precision EVA, 2 Sols away; two separate group trips, 0 today but everyone is busy for 1 Sol tomorrow.
- **S3 (Dusty sensor):** group repair EVA, 1 Sol for everyone; Engineer remote clean-up, 1; abandon it, 0.
- **S4 (Marsquake):** Engineer reinforces structure, 1; group evacuates to safe room, 0. Unwarned quake repair is a group task for 1 Sol.

### Objective 2: MOXIE generator

- **M1 (First MOXIE phase):** general fast assembly, 1 Sol for everyone; Engineer careful assembly, 2 Sols; general greenhouse-parts option, 0.
- **M2 (MOXIE vs. greenhouse):** prioritize MOXIE, 0; Biologist schedules shifts, 1; Generalist shuts down the lab, 1.
- **M3 (Filter failure):** group hand-cleaning EVA, 1 Sol for everyone; Engineer swaps the filter, 1; ignore it, 0.

### Special events

- **Ask Earth for help:** 0 Sols, with either option (full report or quick message).
- **Solar alert (DONKI):** the selected role (Biologist or Engineer) is busy for 1 Sol.

## 4. Implementation

Implemented in `GameState` (`game/Scripts/game_state.gd`); each option's Sols come from `away_sols` / `away_all` in `events.json`.

| Function | Purpose |
|---|---|
| `send_away(role, sols)` / `send_all_away(sols)` | Marks one crew member, or the whole crew, as busy |
| `process_crew_return()` | At dawn, counts down one Sol and returns who is back at the base |
| `is_away(role)`, `away_sols_left(role)`, `available_crew()` | Queries used to lock options and decide who votes |
| `base_is_empty()` | When `true`, no event happens that Sol |
