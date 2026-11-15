# Arquitectura del juego en Godot

Cómo está organizado el código de `game/` (Godot 4.7, GDScript) en la versión entregada. Las reglas y las cifras de diseño están en el [diseño](../juego/diseno.md) y en el [resumen](../resumen.md); la conexión con el backend y los móviles, en [red.md](red.md).

## Principios

- **Guiado por datos:** los eventos, sus opciones y sus cifras viven en [`game/Data/events.json`](../../../game/Data/events.json), y los términos científicos en `game/Data/glossary.json`. Para añadir o equilibrar un evento se edita el JSON, no el código. Las reglas globales (duración, consumo diario, recarga de la ayuda de la Tierra) son constantes de `game_state.gd` y `turn_manager.gd`.
- **Máquina de estados:** el turno (un Sol) pasa por fases fijas dentro de `TurnManager`. Así no hay lógica de reglas repartida por las escenas.
- **Godot es la autoridad:** solo Godot calcula consecuencias. Los móviles envían elecciones; ver la [regla fundamental](../../../CLAUDE.md#regla-fundamental-no-romper-nunca).
- **Un sitio por responsabilidad:** solo `Net` toca el WebSocket, solo `PhoneBridge` traduce entre el juego y los móviles, solo `GameState` cambia recursos (`modify_stat`) y las escenas solo pintan, escuchan señales y llaman a la API pública de `TurnManager`.

## Carpetas

Todos los scripts están en una única carpeta plana, `game/Scripts/`:

```text
game/
  project.godot             autoloads y escena principal (Scenes/Main.tscn)
  Data/
    events.json             16 eventos con sus opciones y cifras ({"version": 3, "events": [...]})
    glossary.json           18 términos del Libro de palabras ({"terms": {...}})
  Scenes/
    Main.tscn               raíz: cambia de escena con fundido, música, NasaApi y Sfx
    Main_menu.tscn          menú, elección de modo (solo / multijugador) y lobby con QR
    Intro.tscn              introducción de la misión por páginas
    Gameplay.tscn           contiene MainUI.tscn
    MainUI.tscn             cabina: ventana de Marte, barras, evento, tripulación, Libro de palabras
    OptionsPanel.tscn       opciones de sonido
  Scripts/
    events.gd               autoload Events: bus de señales
    game_state.gd           autoload GameState: recursos, progreso, condiciones, efectos diferidos
    glossary_manager.gd     autoload GlossaryManager: Libro de palabras
    event_manager.gd        autoload EventManager: carga events.json y elige el evento de cada Sol
    turn_manager.gd         autoload TurnManager: máquina de estados del Sol, votación, ayuda de la Tierra, DONKI
    net.gd                  autoload Net: WebSocket con el backend (ver red.md)
    phone_bridge.gd         autoload PhoneBridge: vistas de los mandos y validación de elecciones
    delayed_effects_queue.gd  DelayedEffectsQueue (RefCounted): cola de efectos diferidos
    nasa_api.gd             NasaApi: imagen de Jezero de NASA Image and Video Library
    ...                     scripts de interfaz (ver tabla de abajo)
```

## Componentes

### Autoloads

En el orden de `project.godot`:

| Autoload | Script | Responsabilidad |
|---|---|---|
| `Events` | `events.gd` | Bus de señales: cambio de escena, sonido (`sfx_requested`) y señales de red que emite `Net` (`room_created`, `lobby_updated`, `game_started`, `player_choice_received`, `room_closed`…). |
| `GameState` | `game_state.gd` | Barras (0–100, empiezan en 80), Sol actual, progreso de objetivos, tripulación fuera (`crew_away`), condiciones multi-Sol (`active_conditions`), cola de efectos diferidos (`delayed_queue`), términos desbloqueados y recarga de la ayuda de la Tierra. Aplica los resultados de las opciones (`apply_outcome`, `apply_failure`), comprueba el final (`check_end`) y calcula la puntuación. **Único sitio que modifica recursos.** Señales: `stats_changed`, `progress_changed`, `conditions_changed`, `crew_changed`, `seismic_alert_activated`. |
| `GlossaryManager` | `glossary_manager.gd` | Carga `glossary.json` y desbloquea términos (los guarda en `GameState.unlocked_terms`). Señal `term_unlocked`. |
| `EventManager` | `event_manager.gd` | Carga `events.json` en un diccionario `id → evento`, filtra por `conditions` y `cooldown_sols`, guarda los eventos programados (`schedule_event`) y elige el evento del Sol (`pick_event`). |
| `TurnManager` | `turn_manager.gd` | Máquina de estados del Sol, tiempo de lectura, cuenta atrás de los eventos críticos, votación de los móviles y desempate, tripulación ocupada, ayuda de la Tierra, eventos en espera y consulta a DONKI. La interfaz solo llama a `start_game()`, `submit_choice()`, `request_earth_help()`, `continue_after_resolution()` y `simulate_solar_flare()` (botón de depuración). |
| `Net` | `net.gd` | Único punto que toca el WebSocket: crear sala, enviar vistas y resultados, cerrar. Emite las señales de red en `Events`. Ver [red.md](red.md). |
| `PhoneBridge` | `phone_bridge.gd` | Une `TurnManager` con los móviles a través de `Net`: decide la `controller_view` de cada rol, valida cada `choose` (evento vigente, jugador, opción, duplicados, idempotencia por `actionId`) y la pasa a `TurnManager.cast_vote()`. Sin sala abierta, el juego funciona en una sola pantalla. |

### Otros scripts

| Script | Qué es |
|---|---|
| `delayed_effects_queue.gd` | `DelayedEffectsQueue` (`RefCounted`): entradas `{due_sol, outcome}`; `pop_due(sol)` devuelve las que vencen. |
| `nasa_api.gd` | `NasaApi` (nodo `HTTPRequest` en `Main.tscn`): busca y descarga una imagen de Jezero en NASA Image and Video Library al arrancar; la intro la muestra con su título. 3 s de espera; si falla, se queda la imagen local. |
| `main.gd` | Raíz de `Main.tscn`: cambia entre menú, intro y partida con fundido y cambia la música. |
| `sfx.gd` | Nodo `Sfx` de `Main.tscn`: reproduce los sonidos pedidos por `Events.sfx_requested`. |
| `main_menu.gd`, `intro.gd`, `options_panel.gd` | Menú (modo solo o multijugador, lobby con código y QR), introducción y opciones de sonido. |
| `main_ui.gd` | Cabina de la partida. Solo muestra el estado y reenvía las decisiones a `TurnManager`; jugando solo, las opciones se eligen con el ratón. |
| `mars_view.gd`, `mars_landscape.gd` | Ventana de Marte: paisaje dibujado por código y el bloque `scene` de cada evento (imagen, encuadre y efecto). |
| `crew_panel.gd`, `crew_avatar.gd` | Los cuatro cascos de la tripulación (gris si está fuera de la base). |
| `glossary_view.gd` | Libro de palabras dentro de la cabina. |
| `earth_panel.gd`, `earth_help_face.gd` | Ventana y botón de «Ask Earth for help». |
| `end_screen.gd` | Pantalla de victoria o derrota con objetivos y puntuación. |
| `option_card.gd`, `option_info.gd` | Tarjeta de opción y textos de costes (`OptionInfo.costs_text`, que también usa el mando como `detail`). |
| `event_button_face.gd`, `stat_icon.gd`, `ui_overlay.gd`, `menu_style.gd` | Piezas de interfaz: botón del evento (exclamación si `important`), iconos de las barras, ventana modal y estilo de botones. |
| `qr_code.gd` | `QrCode`: generador de códigos QR en GDScript, sin servicios externos. |

## Máquina de estados del Sol

```gdscript
enum Phase { IDLE, SOL_START, EVENT_SELECTION, DECISION, RESOLUTION, SOL_END, ENDED }
```

| Fase | Qué pasa |
|---|---|
| `IDLE` | Antes de `start_game()`. |
| `SOL_START` | Amanecer: avanza el Sol y se aplican los cambios automáticos (ver abajo). |
| `EVENT_SELECTION` | Se elige el evento del Sol. |
| `DECISION` | Se muestra el evento. Primero hay un **tiempo de lectura** (`reading`, entre 2,5 y 12 s según la longitud del texto, a 23 letras por segundo) en el que no se acepta ninguna elección; después se vota y, si el evento tiene `timer_seconds`, empieza la cuenta atrás. |
| `RESOLUTION` | Se aplica la opción ganadora. La partida espera a `continue_after_resolution()` (botón en pantalla o «continuar» desde los móviles vía `PhoneBridge`). |
| `SOL_END` | `GameState.check_end()`: derrota si alguna barra llega a 0; victoria al terminar el Sol `GameState.MAX_SOLS` (20); si no, empieza otro Sol. |
| `ENDED` | Fin de partida: se emite `game_ended` con el informe (puntuación, objetivos, términos). |

Lo que significa cada fase para los jugadores está en el [diseño](../juego/diseno.md#bucle-de-un-sol).

### Inicio del Sol

`TurnManager.start_game()` reinicia el estado, desbloquea el término `sol`, consulta DONKI **una sola vez** y empieza el Sol 1 sin cambios automáticos. A partir del Sol 2, `_begin_sol()` hace, en este orden:

1. `current_sol += 1`.
2. Vuelven los tripulantes que han cumplido su tiempo fuera (`process_crew_return`).
3. Cambios automáticos de las barras (constantes de `game_state.gd`):
   - Oxígeno −3 (`PASSIVE_OXYGEN_LOSS`), solo mientras MOXIE no está al 100 %.
   - Energía +7 (`PASSIVE_ENERGY_GAIN`); +6 desde el Sol 8 (`PASSIVE_ENERGY_GAIN_DUSTY`, `DUSTY_PANELS_FROM_SOL`).
   - Integridad −2 (`PASSIVE_INTEGRITY_LOSS`).
   - Salud −4 desde el Sol 4 (`PASSIVE_HEALTH_LOSS`, `HEALTH_LOSS_FROM_SOL`).
4. Efecto diario de cada condición activa y un Sol menos (`process_conditions`); al acabar se aplica su `on_end`.
5. Efectos diferidos que vencen hoy (`process_delayed_effects`).
6. Si la red sísmica acaba de completarse, se programa `quake-warned` para dentro de 1–2 Sols.
7. Comprobación de derrota (alguna barra ≤ 0).
8. Si toda la tripulación está fuera (**base vacía**), ese Sol no hay evento: se muestra un aviso y pasa el día.
9. Selección del evento.

### Selección del evento

`TurnManager._select_event()` elige, por orden de prioridad:

1. La **alerta solar** (`rt-solar-flare`) si DONKI ha devuelto una llamarada M o X y aún no ha salido.
2. Un **evento en espera** cuyo Sol de vuelta ha llegado: un evento por el que se pidió ayuda a la Tierra (vuelve con su pista) o uno que se aplazó porque nadie podía elegir ninguna opción.
3. `EventManager.pick_event()`:
   1. el primer evento `auto` cuyas condiciones se cumplen;
   2. un evento programado que vence hoy (si sus condiciones se siguen cumpliendo);
   3. un evento `objective` (con probabilidad 0,7 si también hay aleatorios; ponderado por `weight`) o, si no, uno `random`;
   4. un evento `filler`.

Un evento no vuelve a salir hasta que pasan `cooldown_sols` Sols (999, una sola vez, si no se indica). Los eventos `scheduled_only` solo salen cuando otro los programa.

Al mostrarse un evento por primera vez se marca como visto, se desbloquean sus `terms` y se aplica su `on_start`. Cada aparición recibe un identificador `"<id>#<n>"`, que es el `eventId` del protocolo (ver [red.md](red.md#eventid-una-aparición-no-una-plantilla)).

### Decisión y resolución

- **Opciones bloqueadas:** una opción con `role` no se puede elegir si ese tripulante está fuera; una opción sin rol con `away_sols` (salida de todos) necesita a toda la tripulación en la base. Si no queda ninguna opción posible, el evento espera hasta que vuelva alguien.
- **Quién vota:** todos los jugadores ven y pueden votar **todas** las opciones (también las de otros roles). Votan los roles con el móvil conectado, en la base y con alguna opción libre (`voters()`). Las elecciones llegan por `Net` → `PhoneBridge` → `cast_vote()`; no se aplican efectos al recibirlas, solo al resolver.
- **Resolución de la votación** (`_try_resolve_votes`): cuando han votado todos, gana la opción más votada. Si hay empate, se vota otra vez **solo entre las empatadas** con un nuevo `eventId` (`"<id>#<n>-tie"`). Si vuelve a empatar, decide el voto del **Comandante** (el primer jugador que entró en la sala; lo marca el backend con `commander`); si el Comandante no votó ninguna de las empatadas, gana la primera en el orden del evento.
- **Cuenta atrás:** al acabar `timer_seconds` gana lo más votado hasta ese momento (en empate, `timeout_option` si está entre las empatadas). Sin votos, se elige `timeout_option` o, si está bloqueada, la primera opción libre.
- **Partida en una sola pantalla:** sin móviles, `main_ui.gd` llama directamente a `submit_choice()`.
- **Éxito o fallo** (`submit_choice`): se tira contra `success_chance` (1,0 si no se indica). Si sale bien, se muestra `feedback`, se aplica el resultado (`apply_outcome`) y su `schedule_event`. Si falla, se muestra `fail_feedback`, se pagan solo los costes (efectos negativos), se pierden ganancias, progreso y efectos diferidos, y se aplica `on_fail`; si el evento tiene `retry_on_fail`, puede volver a salir. En ambos casos, `away_sols` deja ocupado al rol de la opción (o a toda la tripulación).

### Ayuda de la Tierra

`can_request_earth_help()` exige estar en la decisión (pasado el tiempo de lectura), que la ayuda esté recargada, que ninguna condición activa tenga `blocks_earth_help` y que el evento tenga `earth_hint` y no sea `realtime`, `auto` ni tenga cuenta atrás.

Las formas de pedirla están en `TurnManager.EARTH_HELP_OPTIONS`:

| `id` | Coste | Respuesta |
|---|---|---|
| `full-report` | −5 Energía | en 1 Sol |
| `quick-message` | gratis | en 2 Sols |

Al pedirla, el evento actual queda en espera y el Sol termina. Cuando llega la respuesta, el evento vuelve a salir con su `earth_hint` como pista. La ayuda se recarga en `GameState.EARTH_HELP_COOLDOWN_SOLS` = 4 Sols, contados desde el Sol en que se pide.

### Alerta solar (DONKI)

`start_game()` consulta una vez `DONKI/FLR` (llamaradas de los últimos 3 días, 3 s de espera). Si hay una de clase M o X, el evento `realtime` `rt-solar-flare` sale en la siguiente selección de evento, con los datos reales añadidos a su descripción. Si la consulta falla, no hay alerta. El botón de depuración `simulate_solar_flare()` la provoca al momento e interrumpe el evento en curso, que se retoma después.

## Formato de `events.json`

```json
{
  "version": 3,
  "events": [ { "id": "greenhouse-dilemma", "kind": "random", "options": [ ... ] } ]
}
```

Los eventos y las opciones son **diccionarios** tal cual salen del JSON; no hay clases de modelo. El catálogo completo está en el [resumen](../resumen.md#6-catálogo-de-eventos).

### Evento

| Campo | Tipo | Para qué |
|---|---|---|
| `id` | String | Plantilla del evento. Cada aparición recibe su propio `eventId` (`"<id>#<n>"`). |
| `kind` | `random` · `objective` · `filler` · `auto` · `realtime` | Tipo; decide la prioridad en la selección. |
| `title`, `description` | String | Texto en pantalla. La longitud de `description` fija el tiempo de lectura. |
| `nasa_fact` | String | Dato real de la NASA que se muestra con el evento. |
| `terms` | Array de ids | Términos del glosario que se desbloquean al salir. |
| `conditions` | Objeto · `null` | Cuándo puede salir (ver abajo). |
| `cooldown_sols` | int | Sols antes de que pueda repetirse (999 por defecto: una vez). |
| `weight` | número | Peso al elegir entre eventos `objective` (1 por defecto). |
| `scheduled_only` | bool | Solo sale si otro evento lo programa. |
| `important` | bool | La interfaz marca el botón del evento con una exclamación. |
| `timer_seconds`, `timeout_option` | int, String | Cuenta atrás de los eventos críticos y opción por defecto al acabar. |
| `on_start` | resultado | Se aplica al mostrarse el evento. |
| `earth_hint` | String | Pista que trae la respuesta de la Tierra; sin ella no se puede pedir ayuda. |
| `retry_on_fail` | bool | Si la opción elegida falla, el evento puede volver a salir. |
| `scene` | `{image, pan, effect, intensity}` | Imagen de la ventana de Marte (`effect`: `none`, `dust`, `flare`, `quake`, `dark`, `green`, `cool`). |
| `options` | Array | Ver abajo. |

### Condiciones

Todas son opcionales y se combinan con Y (`EventManager.conditions_met`):

| Clave | Se cumple si… |
|---|---|
| `min_sol`, `max_sol` | el Sol actual está en ese rango. |
| `state` `{prop: valor}` | `GameState.prop == valor`. |
| `state_gt`, `state_lt` `{prop: n}` | `GameState.prop > n` / `< n`. |
| `any_of` `[condición, …]` | se cumple al menos una. |

### Opción

| Campo | Tipo | Para qué |
|---|---|---|
| `id`, `label` | String | `id` es el `optionId` del protocolo. |
| `role` | String · `null` | Rol que hace la tarea (`engineer`, `biologist`, `doctor`, `generalist`) o `null` si es de todos. Todos pueden votarla. |
| `success_chance` | 0–1 | Probabilidad de éxito. |
| `feedback`, `fail_feedback` | String | Texto si sale bien / si falla. |
| `effects` | `{barra: número}` | Cambios inmediatos en `health`, `oxygen`, `energy`, `integrity`. |
| `set`, `add` | `{prop: valor}` | Fijan o suman una propiedad de progreso de `GameState` (lista blanca `SETTABLE`). |
| `chance` | `[{probability, effects, text}]` | Efectos extra con azar. |
| `delayed` | `[{after_sols, …}]` | Resultado que se aplica dentro de `after_sols` Sols (`effects`, `set`, `add`, `text`, `away_all`). |
| `start_condition` | `{id, name, sols, daily \| sequence, blocks_earth_help?, on_end?}` | Activa un problema que dura varios Sols. |
| `schedule_event` | `{id, min_sols, max_sols}` | Programa otro evento. |
| `on_fail` | resultado | Castigo extra si la opción falla. |
| `away_sols` | int | Sols que queda ocupado el rol de la opción (o toda la tripulación si `role` es `null`). |

Un **resultado** (*outcome*) es un diccionario con cualquiera de las claves `effects`, `set`, `add`, `chance`, `delayed`, `start_condition` (y `away_all` en los diferidos); lo aplica `GameState.apply_outcome()`. Las propiedades que se pueden escribir son `sensors_fabricated`, `sensors_placed`, `moxie_progress`, `rover_rescued`, `quake_happened`, `e2_pending` y `harvests_completed`.

## Estado en tiempo de ejecución

Todo son diccionarios y arrays dentro de los autoloads:

| Dónde | Forma |
|---|---|
| `GameState.active_conditions` | `[{id, name, sols, sols_left, step, daily \| sequence, blocks_earth_help?, on_end?}]` |
| `GameState.delayed_queue` | `DelayedEffectsQueue` con `[{due_sol, outcome}]` |
| `GameState.crew_away` | `{rol: Sol en que vuelve}` |
| `EventManager._scheduled` | `[{id, due_sol}]` |
| `TurnManager._paused_events` | `[{event, return_sol, hint, fresh?}]` (ayuda de la Tierra o evento aplazado) |
| `TurnManager._votes` | `{rol: optionId}` |

Objetivos (`GameState.objectives_status()`): salud siempre por encima de 50, 3 cosechas, rescatar el rover, 3 sensores colocados (la alerta sísmica solo se activa antes del Sol `SEISMIC_DEADLINE_SOL` = 13) y MOXIE al 100 %. Puntuación: 200 por objetivo más la media de las cuatro barras.

## Libro de palabras (`glossary.json`)

`{"terms": {"<id>": {"title", "definition", "nasa_fact"}}}`, con 18 términos. Se desbloquean con el campo `terms` de cada evento (y `sol` al empezar, `minutos_luz` al pedir ayuda a la Tierra). El dibujo de cada término es `res://Images/Glossary/<id>.png`.

## Astronauta y habilidades (descartado)

El documento original de clases proponía un `AstronautData` por jugador con salud individual y una **destreza por área** que cambiaba la probabilidad de éxito y el coste (Experto 95 % y ×0,5; Normal 75 % y ×1; Novato 45 % y ×1,5). Se descartó (ver [decisiones de diseño](../juego/diseno.md#decisiones-de-diseño)): la salud es común y cada opción de `events.json` lleva su propio `role` y su `success_chance`.

## Cambios respecto al documento original de clases

El documento de clases proponía modelos `RefCounted` (`MissionEvent`, `EventOption`, `MissionObjective`, `EarthTransmission`, `ActiveConditions`) creados desde el JSON. La versión entregada lo simplifica a **diccionarios del JSON + gestores (autoloads)**:

| Antes (PDF de clases) | Ahora | Motivo |
|---|---|---|
| Clases de modelo `MissionEvent`, `EventOption`, `MissionObjective` | Diccionarios de `events.json`; objetivos como propiedades de `GameState` | Menos código que mantener; el JSON es la única definición. |
| `ActiveConditions` y `EarthTransmission` | `GameState.active_conditions` y eventos en espera de `TurnManager` con `earth_hint` | Mismo comportamiento sin clases extra. |
| `WebSocketBridge` con acciones `JOIN_ROLE`, `SUBMIT_EVENT_CHOICE` y URL `ws://localhost:8000/ws/godot` | Autoloads `Net` y `PhoneBridge` con los mensajes del [contrato](../protocol.md) en `/ws` | Ese protocolo no existe en el backend. Ver [red.md](red.md). |
| Roles como `enum` `ENGINEER, BIOLOGIST, MEDIC, COMMANDER` | Strings `engineer`, `biologist`, `doctor`, `generalist`; Comandante como capacidad del primer jugador | Son los ids del contrato y de `events.json`. |
| Tripulación fija de 4 astronautas | Jugadores según `game_started` (1 a 4); todos votan todas las opciones | Se puede jugar con menos de 4. |
| `required_role`, `next_sol_effects`, `objective_progress` | `role`, `delayed`, `set` / `add` | Nombres de `events.json`. |
| `MAX_SOLS = 15` | `GameState.MAX_SOLS = 20` | Duración de la versión entregada. |
| Catálogo de ayuda de la Tierra con recompensas (`EARTH_CATALOG`) | `EARTH_HELP_OPTIONS`: el evento espera y vuelve con una pista (`earth_hint`) | La ayuda es una pista, no una recompensa de recursos. |

El código completo original sigue en el historial de git (`docs/Clases Godot.pdf`).
