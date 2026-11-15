# Arquitectura del juego en Godot

Cómo organizar el código de `game/` para implementar el [diseño](../juego/diseno.md). La conexión con el backend y los móviles está en [red.md](red.md).

## Principios

- **Guiado por datos:** los eventos, objetivos y reglas viven en [`game/Data/events.json`](../../../game/Data/events.json). Para añadir o equilibrar un evento se edita el JSON, no el código.
- **Máquina de estados:** el turno (un Sol) pasa por fases fijas. Así no hay lógica repartida por las escenas.
- **Godot es la autoridad:** solo Godot calcula consecuencias. Los móviles envían elecciones; ver la [regla fundamental](../../../CLAUDE.md#regla-fundamental-no-romper-nunca).
- **Un sitio por responsabilidad:** solo `Net` toca el WebSocket, solo `GameState` cambia recursos y las escenas solo pintan y escuchan señales.

## Carpetas

Propuesta dentro de la estructura actual de `game/`:

```text
game/
  Data/events.json          eventos, objetivos y reglas
  Scripts/
    events.gd               autoload Events: bus de señales (ya existe)
    nasa_api.gd             búsqueda NASA Image and Video Library para la imagen de intro
    net.gd                  autoload Net: WebSocket con el backend (ver red.md)
    autoload/
      game_state.gd         recursos, objetivos, Sol actual, condiciones activas
      event_manager.gd      carga events.json y elige el evento de cada Sol
      turn_manager.gd       máquina de estados del Sol
      glossary.gd           Libro de tecnicismos
    models/
      mission_event.gd      MissionEvent (un evento de events.json)
      event_option.gd       EventOption (una opción)
      mission_objective.gd  MissionObjective
      earth_transmission.gd EarthTransmission (ayuda de la Tierra en camino)
  Scenes/                   pantallas (solo pintan y escuchan señales)
```

## Componentes

| Componente | Responsabilidad | Notas |
|---|---|---|
| `Events` (autoload) | Bus de señales entre sistemas y escenas. | Ya existe en `game/Scripts/events.gd`. |
| `GameState` (autoload) | Recursos (0–100), objetivos, Sol actual, eventos pendientes, `active_conditions`, cola de efectos diferidos, ayuda de la Tierra usada hoy. **Único sitio que modifica recursos.** | Emite `stats_updated`. |
| `EventManager` | Carga `events.json`, filtra los eventos válidos según `condition` y elige uno. Desbloquea los términos del glosario. | |
| `TurnManager` | Máquina de estados del Sol (ver abajo). Decide cuándo abrir, resolver y avanzar. | |
| `ActiveConditions` | Eventos que duran varios Sols (tormentas, eventos pospuestos) y aplican su castigo cada mañana. | Puede ser una parte de `GameState`. |
| `DelayedEffectsQueue` | Efectos programados para un Sol futuro (cosechas, respuestas de la Tierra). | Puede ser una parte de `GameState`. |
| `GlossaryManager` | Términos científicos: título, definición sencilla y dato NASA. Guarda los desbloqueados. | Mínimo 10 términos para empezar. |
| `NasaApi` (`game/Scripts/nasa_api.gd`) | Busca y descarga una imagen de Jezero en NASA Image and Video Library al iniciar el juego; la intro muestra la imagen y su título. | 3 s de espera; usa la imagen local si falla. |
| `TurnManager` (`game/Scripts/turn_manager.gd`) | Consulta DONKI `/DONKI/FLR` al comenzar una partida para detectar llamaradas M/X de los últimos 3 días. | 3 s de espera; sin alerta en caso de fallo y botón de depuración para simularla. |
| `Net` | Sala, lobby, vistas de los mandos y elecciones. | [red.md](red.md) |

## Máquina de estados del Sol

```gdscript
enum Phase { SOL_START, EVENT_SELECTION, DECISION, RESOLUTION, SOL_END }
```

Lo que hace cada fase está en el [diseño](../juego/diseno.md#bucle-de-un-sol). El orden dentro del **inicio del Sol** importa:

1. Consumo pasivo: −5 Energía y −5 Oxígeno (el oxígeno, solo si MOXIE no está terminado). *El −5 de Energía solo aparece en el código de las clases; confirmadlo.*
2. Efectos diferidos que tocan hoy.
3. Castigo diario de las `active_conditions`; se resta 1 a sus Sols restantes.
4. Llegada de las transmisiones de la Tierra: se resta 1 a cada una y se aplica la recompensa de las que llegan a 0.
5. Se reinicia «ayuda de la Tierra usada hoy».
6. Comprobación de derrota (algún recurso ≤ 0).
7. Consulta de la alerta solar.

Durante la **decisión**, las elecciones llegan por `Net`. `TurnManager` no aplica efectos al recibirlas: solo en la **resolución**.

## Formato de `events.json`

```json
{
  "version": 1,
  "rules": { "max_sols": 30, "passive_oxygen_loss": 5, "max_pending_events": 2, "bars": ["energy", "oxygen", "integrity", "health"] },
  "objectives": { "sensors": { "...": "..." }, "moxie": { "...": "..." } },
  "earth_help": { "max_requests_per_sol": 1, "delay_sols_min": 2, "delay_sols_max": 3, "mode": "discard_option" },
  "events": [ { "id": "solar-storm", "...": "..." } ]
}
```

### Evento

| Campo | Tipo | Para qué |
|---|---|---|
| `id` | String | Plantilla del evento. El `eventId` del protocolo es **una aparición** (`solar-storm#1`): ver [red.md](red.md#eventid-una-aparición-no-una-plantilla). |
| `category` | `"random"` · `"objective"` | Aleatorio o parte de una cadena de objetivo. |
| `objective` | String | Objetivo al que pertenece (`sensors`, `moxie`). |
| `title`, `description` | String | Texto en pantalla. |
| `nasa_source`, `real_fact` | String · null | Fuente y dato real para mostrar. |
| `mode` | `"vote"` | Cómo se decide. |
| `condition` | Objeto · null | Cuándo puede salir: `min_sol`, `max_sol`, `or_pending`, `requires_done`, `requires_not`, `triggered_by`, `objective_active`, `objective_progress`, `sensors_placed_before_sol`. |
| `persistent`, `decay`, `on_decay_end` | | Evento que castiga cada Sol mientras no se resuelve. `decay` es la lista de efectos de cada Sol. |
| `earth_discard` | String | Opción que descarta la ayuda de la Tierra. |
| `options` | Array | Ver abajo. |

### Opción

| Campo | Tipo | Para qué |
|---|---|---|
| `id`, `label` | String | `id` es el `optionId` del protocolo. |
| `role` | String · null | `null` = votación general; si no, el rol (`engineer`, `biologist`, `doctor`, `generalist`). |
| `nfc_tool` | String · null | Etiqueta NFC que activa la opción. |
| `effects` | `{ recurso: número }` | Efectos inmediatos. |
| `delayed_effects` | `[{ after_sols, effects, progress? }]` | Efectos en Sols futuros. |
| `chance_effects` | `[{ probability, effects, feedback }]` | Efectos con azar. |
| `progress` | `{ clave: número }` | Avance de objetivo (`moxie`, `sensors_fabricated`, `sensors_placed`). |
| `defer` | bool | Posponer: el evento queda pendiente y aplica su `decay`. |
| `triggers_event`, `reopen_event`, `unlocks` | | Encadenar eventos o cambiar reglas (p. ej. `passive_oxygen_loss: 0`). |
| `feedback` | String | Texto de resultado. |

## Modelos de datos

Clases ligeras (`RefCounted`) que se crean desde el JSON. Usan los mismos nombres de campo que `events.json`.

### EventOption y MissionEvent

```gdscript
# game/Scripts/models/event_option.gd
class_name EventOption
extends RefCounted

var id: String
var label: String
var role: String               # "" = votación general; si no, "engineer", "biologist"...
var nfc_tool: String           # p. ej. "NFC_SHIELD"; "" si no hay
var effects: Dictionary        # {"energy": -15, "oxygen": 10}
var delayed_effects: Array     # [{"after_sols": 1, "effects": {...}}]
var chance_effects: Array      # [{"probability": 0.5, "effects": {...}, "feedback": "..."}]
var progress: Dictionary       # {"moxie": 33}
var feedback: String

static func from_dict(data: Dictionary) -> EventOption:
	var opt := EventOption.new()
	opt.id = data.get("id", "")
	opt.label = data.get("label", "")
	opt.role = data.get("role") if data.get("role") != null else ""
	opt.nfc_tool = data.get("nfc_tool") if data.get("nfc_tool") != null else ""
	opt.effects = data.get("effects", {})
	opt.delayed_effects = data.get("delayed_effects", [])
	opt.chance_effects = data.get("chance_effects", [])
	opt.progress = data.get("progress", {})
	opt.feedback = data.get("feedback", "")
	return opt
```

```gdscript
# game/Scripts/models/mission_event.gd
class_name MissionEvent
extends RefCounted

var id: String
var category: String           # "random" | "objective"
var title: String
var description: String
var nasa_source: String
var real_fact: String
var condition: Dictionary
var options: Array[EventOption] = []

static func from_dict(data: Dictionary) -> MissionEvent:
	var ev := MissionEvent.new()
	ev.id = data.get("id", "")
	ev.category = data.get("category", "random")
	ev.title = data.get("title", "")
	ev.description = data.get("description", "")
	ev.nasa_source = data.get("nasa_source", "")
	ev.real_fact = data.get("real_fact") if data.get("real_fact") != null else ""
	ev.condition = data.get("condition") if data.get("condition") != null else {}
	for opt_data in data.get("options", []):
		ev.options.append(EventOption.from_dict(opt_data))
	return ev

## Opciones que se pueden ofrecer con los roles presentes.
func available_options(present_roles: Array) -> Array[EventOption]:
	var result: Array[EventOption] = []
	for opt in options:
		if opt.role == "" or opt.role in present_roles:
			result.append(opt)
	return result
```

### MissionObjective

```gdscript
# game/Scripts/models/mission_objective.gd
class_name MissionObjective
extends RefCounted

var id: String
var title: String
var description: String
var current_progress := 0
var target_progress := 1
var is_completed := false
var is_failed := false

func _init(_id: String, _title: String, _desc: String, _target: int) -> void:
	id = _id
	title = _title
	description = _desc
	target_progress = _target

## Devuelve true solo en el turno en que se completa.
func add_progress(amount: int) -> bool:
	if is_completed or is_failed:
		return false
	current_progress = clamp(current_progress + amount, 0, target_progress)
	if current_progress >= target_progress:
		is_completed = true
		return true
	return false

func fail() -> void:
	if not is_completed:
		is_failed = true
```

### EarthTransmission

Una petición de ayuda a la Tierra que está en camino.

```gdscript
# game/Scripts/models/earth_transmission.gd
class_name EarthTransmission
extends RefCounted

var event_id: String           # evento sobre el que se pidió ayuda
var sols_remaining: int        # Sols que faltan para que llegue la respuesta
var discard_option: String     # opción que se descarta al llegar (earth_discard)
var arrival_message: String

func _init(_event_id: String, _delay: int, _discard: String, _msg: String) -> void:
	event_id = _event_id
	sols_remaining = _delay
	discard_option = _discard
	arrival_message = _msg
```

### Astronauta y habilidades (descartado)

El documento original de clases proponía un `AstronautData` por jugador con salud individual y una **destreza por área** que cambia la probabilidad de éxito y el coste:

| Destreza | Éxito | Coste |
|---|---|---|
| 3 · Experto | 95 % | ×0,5 |
| 2 · Normal | 75 % | ×1 |
| 1 · Novato | 45 % | ×1,5 |

Se descartó (ver [decisiones de diseño](../juego/diseno.md#decisiones-de-diseño)): la salud es común y cada opción de `events.json` lleva su propio rol y su `success_chance`.

## Cambios respecto al documento original de clases

Para que el código cuadre con `events.json` y con el [contrato](../protocol.md):

| Antes (PDF de clases) | Ahora | Motivo |
|---|---|---|
| `WebSocketBridge` con acciones `JOIN_ROLE`, `SUBMIT_EVENT_CHOICE` y URL `ws://localhost:8000/ws/godot` | Autoload `Net` con los mensajes del protocolo (`create_room`, `choose`, `controller_view`…) en `/ws` | Ese protocolo no existe en el backend. Ver [red.md](red.md). |
| Roles como `enum` `ENGINEER, BIOLOGIST, MEDIC, COMMANDER` | Strings `engineer`, `biologist`, `doctor`, `generalist` | Son los ids del contrato y de `events.json`. |
| Tripulación fija de 4 astronautas | Jugadores según `game_started` (1 a 4) | Se puede jugar con menos de 4. |
| `required_role`, `next_sol_effects`, `objective_progress` | `role`, `delayed_effects`, `progress` | Nombres de `events.json`. |
| `MAX_SOLS = 15` en el código | `rules.max_sols` | La regla vive en los datos. |
| Catálogo de ayuda de la Tierra con recompensas (`EARTH_CATALOG`) | `earth_help` en `events.json`: descarta una opción | Pendiente de decidir. |

El código completo original sigue en el historial de git (`docs/Clases Godot.pdf`).
