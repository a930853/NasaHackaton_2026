extends Node
## Autoload "EventManager": base de datos de eventos (res://Data/events.json) y
## lógica para decidir qué evento puede salir cada Sol.
##
## Campos de un evento: id, kind (random | objective | filler | auto | realtime),
## title, description, nasa_fact, terms, conditions, cooldown_sols, scheduled_only,
## timer_seconds, timeout_option, on_start, earth_hint, weight (peso al elegir entre objetivos), options[].
##
## Condiciones (todas opcionales, se combinan con AND):
##   min_sol / max_sol           rango de Sol actual
##   state     {prop: valor}     GameState.prop == valor
##   state_gt  {prop: n}         GameState.prop > n
##   state_lt  {prop: n}         GameState.prop < n
##   any_of    [condición, ...]  al menos una se cumple

const EVENTS_PATH: String = "res://Data/events.json"
const OBJECTIVE_PRIORITY: float = 0.7  ## probabilidad de elegir objetivo si hay uno disponible
const DEFAULT_COOLDOWN: int = 999       ## sin cooldown definido: el evento sale una sola vez

var _events: Dictionary = {}                 # id -> evento
var _last_seen: Dictionary = {}              # id -> Sol en que salió por última vez
var _scheduled: Array[Dictionary] = []       # [{id, due_sol}]


func _ready() -> void:
	var file: FileAccess = FileAccess.open(EVENTS_PATH, FileAccess.READ)
	if file == null:
		push_error("EventManager: could not open " + EVENTS_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("EventManager: invalid JSON in " + EVENTS_PATH)
		return
	for event in parsed.get("events", []):
		_events[str(event["id"])] = event


func reset() -> void:
	_last_seen.clear()
	_scheduled.clear()


func get_event(event_id: String) -> Dictionary:
	return _events.get(event_id, {})


## Programa un evento para dentro de min_sols..max_sols Soles.
func schedule_event(event_id: String, min_sols: int, max_sols: int) -> void:
	if not _events.has(event_id):
		push_warning("EventManager: unknown event '%s'." % event_id)
		return
	var due: int = GameState.current_sol + randi_range(min_sols, max_sols)
	_scheduled.append({"id": event_id, "due_sol": due})


func mark_seen(event_id: String) -> void:
	_last_seen[event_id] = GameState.current_sol


## Permite que un evento vuelva a salir (tras fallar una tarea con "retry_on_fail").
func clear_seen(event_id: String) -> void:
	_last_seen.erase(event_id)


## Elige el evento del Sol actual. Orden: automáticos > programados > objetivo/aleatorio > relleno.
func pick_event() -> Dictionary:
	var auto_event: Dictionary = _first_valid("auto")
	if not auto_event.is_empty():
		return auto_event

	var scheduled_event: Dictionary = _pop_due_scheduled()
	if not scheduled_event.is_empty():
		return scheduled_event

	var objectives: Array[Dictionary] = _valid_events("objective")
	var randoms: Array[Dictionary] = _valid_events("random")
	if not objectives.is_empty() and (randoms.is_empty() or randf() < OBJECTIVE_PRIORITY):
		return _weighted_pick(objectives)
	if not randoms.is_empty():
		return randoms.pick_random()

	var fillers: Array[Dictionary] = _valid_events("filler")
	return fillers.pick_random() if not fillers.is_empty() else {}


## Elige uno al azar según el campo "weight" del evento (1 si no lo tiene). Los eventos de MOXIE
## pesan el doble para que la fábrica de oxígeno no se retrase demasiado.
func _weighted_pick(candidates: Array[Dictionary]) -> Dictionary:
	var total: float = 0.0
	for event in candidates:
		total += float(event.get("weight", 1.0))
	var roll: float = randf() * total
	for event in candidates:
		roll -= float(event.get("weight", 1.0))
		if roll <= 0.0:
			return event
	return candidates[candidates.size() - 1]


# --- Filtrado ---

func _valid_events(kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in _events.values():
		if event.get("kind", "") != kind:
			continue
		if event.get("scheduled_only", false):
			continue
		if _is_available(event):
			result.append(event)
	return result


func _first_valid(kind: String) -> Dictionary:
	var candidates: Array[Dictionary] = _valid_events(kind)
	return candidates[0] if not candidates.is_empty() else {}


func _is_available(event: Dictionary) -> bool:
	var event_id: String = event["id"]
	if _last_seen.has(event_id):
		var cooldown: int = int(event.get("cooldown_sols", DEFAULT_COOLDOWN))
		if GameState.current_sol - int(_last_seen[event_id]) < cooldown:
			return false
	return conditions_met(event.get("conditions"))


func _pop_due_scheduled() -> Dictionary:
	for i in range(_scheduled.size()):
		if int(_scheduled[i]["due_sol"]) <= GameState.current_sol:
			var event: Dictionary = get_event(str(_scheduled[i]["id"]))
			_scheduled.remove_at(i)
			if not event.is_empty() and conditions_met(event.get("conditions")):
				return event
			return {}
	return {}


func conditions_met(conditions: Variant) -> bool:
	if conditions == null:
		return true
	var cond: Dictionary = conditions
	if cond.has("min_sol") and GameState.current_sol < int(cond["min_sol"]):
		return false
	if cond.has("max_sol") and GameState.current_sol > int(cond["max_sol"]):
		return false
	var state: Dictionary = cond.get("state", {})
	for prop in state:
		if GameState.get(str(prop)) != state[prop]:
			return false
	var greater: Dictionary = cond.get("state_gt", {})
	for prop in greater:
		if int(GameState.get(str(prop))) <= int(greater[prop]):
			return false
	var lower: Dictionary = cond.get("state_lt", {})
	for prop in lower:
		if int(GameState.get(str(prop))) >= int(lower[prop]):
			return false
	if cond.has("any_of"):
		var any_met: bool = false
		for sub_condition in cond["any_of"]:
			if conditions_met(sub_condition):
				any_met = true
				break
		if not any_met:
			return false
	return true
