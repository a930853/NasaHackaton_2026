extends Node
## Autoload "TurnManager": máquina de estados del Sol (1 evento principal por Sol).
##
##   SOL_START -> EVENT_SELECTION -> DECISION -> RESOLUTION -> SOL_END -> (siguiente Sol | fin)
##
## El tiempo avanza solo por turnos (sin reloj continuo). La única cuenta atrás es la de
## los eventos críticos (campo "timer_seconds" del evento, 20 s en el terremoto).
## La UI (hoy botones, mañana móviles/NFC) solo llama a submit_choice(), request_earth_help()
## y continue_after_resolution(); toda la lógica de reglas vive aquí y en GameState.

enum Phase { IDLE, SOL_START, EVENT_SELECTION, DECISION, RESOLUTION, SOL_END, ENDED }

signal phase_changed(phase: int)
signal sol_started(sol: int, summary_lines: Array)
signal event_presented(event: Dictionary, earth_hint: String)
signal decision_resolved(option: Dictionary, feedback: String, success: bool)
signal timer_updated(seconds_left: int)
signal earth_help_changed
signal game_ended(victory: bool, report: Dictionary)

const FLARE_URL: String = "https://api.nasa.gov/DONKI/FLR?startDate=%s&api_key=%s"
const API_KEY: String = "DEMO_KEY"  # límite bajo: usar una key gratuita de api.nasa.gov en la demo
const FLARE_EVENT_ID: String = "rt-solar-flare"
const REQUEST_TIMEOUT: float = 3.0
const FLARE_LOOKBACK_DAYS: int = 3

## Distancia Tierra-Marte de respaldo (no se consulta JPL Horizons en este prototipo).
const EARTH_DISTANCE_TEXT: String = "Mars is about 225 million km from Earth right now. A radio message takes about 12 minutes to get there!"

const EARTH_HELP_OPTIONS: Array[Dictionary] = [
	{"id": "full-report", "label": "Send a full report (Commander)\nCosts: Energy -5  |  Answer in 1 Sol",
		"energy_cost": 5, "delay_sols": 1},
	{"id": "quick-message", "label": "Send a quick message\nCosts: nothing  |  Answer in 2 Sols",
		"energy_cost": 0, "delay_sols": 2},
]

var phase: int = Phase.IDLE
var current_event: Dictionary = {}

var _first_sol: bool = true
var _flare_pending: bool = false
var _flare_triggered: bool = false
var _flare_info: Dictionary = {}
var _paused_events: Array[Dictionary] = []   # {event, return_sol, hint}
var _interrupted_event: Dictionary = {}
var _countdown: float = 0.0
var _countdown_active: bool = false
var _last_second: int = -1
var _http: HTTPRequest = null


func _ready() -> void:
	set_process(false)
	_http = HTTPRequest.new()
	_http.timeout = REQUEST_TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_flare_response)


func _process(delta: float) -> void:
	if not _countdown_active:
		return
	_countdown -= delta
	var seconds: int = ceili(maxf(_countdown, 0.0))
	if seconds != _last_second:
		_last_second = seconds
		timer_updated.emit(seconds)
	if _countdown <= 0.0:
		_on_countdown_finished()


# ---------------------------------------------------------------- Partida

func start_game() -> void:
	GameState.reset()
	EventManager.reset()
	_paused_events.clear()
	_interrupted_event = {}
	_flare_triggered = false
	_first_sol = true
	GlossaryManager.unlock("sol")
	_fetch_flare()
	_begin_sol()


# ------------------------------------------------------------ FASE_INICIO_SOL

func _begin_sol() -> void:
	_set_phase(Phase.SOL_START)
	var lines: Array[String] = []
	if _first_sol:
		_first_sol = false
	else:
		GameState.current_sol += 1
		GameState.earth_help_used_this_sol = false
		var loss: int = GameState.passive_oxygen_loss()
		if loss > 0:
			GameState.modify_stat("oxygen", -loss)
			lines.append("Everyone breathed: Oxygen -%d." % loss)
		if GameState.PASSIVE_ENERGY_GAIN > 0:
			GameState.modify_stat("energy", GameState.PASSIVE_ENERGY_GAIN)
			lines.append("Sunshine! The solar panels made Energy +%d." % GameState.PASSIVE_ENERGY_GAIN)
		lines.append_array(GameState.process_conditions())
		lines.append_array(GameState.process_delayed_effects())
		lines.append_array(_after_state_change())
	earth_help_changed.emit()
	sol_started.emit(GameState.current_sol, lines)
	if GameState.check_end().begins_with("defeat"):
		_finish(false, GameState.check_end())
		return
	_select_event()


# ------------------------------------------------------- FASE_SELECCION_EVENTO

func _select_event() -> void:
	_set_phase(Phase.EVENT_SELECTION)
	var event: Dictionary = {}
	var hint: String = ""

	if _flare_pending and not _flare_triggered:
		event = EventManager.get_event(FLARE_EVENT_ID)
		_flare_triggered = true
		_flare_pending = false

	if event.is_empty():
		var index: int = _due_paused_index()
		if index >= 0:
			var entry: Dictionary = _paused_events.pop_at(index)
			event = entry["event"]
			hint = str(entry["hint"])

	if event.is_empty():
		event = EventManager.pick_event()

	if event.is_empty():
		push_error("TurnManager: no event available on Sol %d." % GameState.current_sol)
		_end_sol()
		return
	_present_event(event, hint, true)


func _due_paused_index() -> int:
	for i in range(_paused_events.size()):
		if int(_paused_events[i]["return_sol"]) <= GameState.current_sol:
			return i
	return -1


# ---------------------------------------------------------------- FASE_DECISION

## `fresh` = false cuando se vuelve a mostrar un evento interrumpido (no repite efectos de inicio).
func _present_event(event: Dictionary, hint: String, fresh: bool) -> void:
	var shown: Dictionary = event.duplicate(true)
	if shown.get("kind", "") == "realtime" and not _flare_info.is_empty():
		shown["description"] = "%s\n\nReal NASA data (DONKI): a class %s solar flare was seen on %s." % [
			shown["description"], _flare_info.get("classType", "M/X"),
			str(_flare_info.get("beginTime", "?")).substr(0, 10)]
	current_event = shown

	if fresh:
		EventManager.mark_seen(str(event["id"]))
		GlossaryManager.unlock_many(event.get("terms", []))
		if event.has("on_start"):
			GameState.apply_outcome(event["on_start"])
			if GameState.check_end().begins_with("defeat"):
				_finish(false, GameState.check_end())
				return

	_set_phase(Phase.DECISION)
	earth_help_changed.emit()
	event_presented.emit(shown, hint)
	_start_countdown(shown)


func submit_choice(option_id: String) -> bool:
	if phase != Phase.DECISION:
		return false
	var option: Dictionary = _find_option(current_event, option_id)
	if option.is_empty():
		return false
	_stop_countdown()

	# ---- FASE_RESOLUCION ----
	_set_phase(Phase.RESOLUTION)
	# Cada opción puede fallar ("success_chance", 1.0 si no se indica).
	var success: bool = randf() <= float(option.get("success_chance", 1.0))
	var lines: Array[String] = []
	if success:
		lines.append(str(option.get("feedback", "")))
		lines.append_array(GameState.apply_outcome(option))
		if option.has("schedule_event"):
			var schedule: Dictionary = option["schedule_event"]
			EventManager.schedule_event(str(schedule["id"]), int(schedule.get("min_sols", 1)), int(schedule.get("max_sols", 1)))
	else:
		lines.append(str(option.get("fail_feedback", "Oh no! It did not work this time.")))
		lines.append("You still used up the energy and air for the try.")
		lines.append_array(GameState.apply_failure(option))
		if current_event.get("retry_on_fail", false):
			EventManager.clear_seen(str(current_event["id"]))
			lines.append("The problem is still there, so you can try again.")
	lines.append_array(_after_state_change())
	decision_resolved.emit(option, "\n".join(PackedStringArray(lines)), success)
	return true


func continue_after_resolution() -> void:
	if phase != Phase.RESOLUTION:
		return
	if not _interrupted_event.is_empty():
		var event: Dictionary = _interrupted_event
		_interrupted_event = {}
		_present_event(event, "", false)
		return
	_end_sol()


# ---------------------------------------------------------------- FASE_FIN_SOL

func _end_sol() -> void:
	_set_phase(Phase.SOL_END)
	var result: String = GameState.check_end()
	if result.begins_with("defeat"):
		_finish(false, result)
	elif result == "victory":
		_finish(true, result)
	else:
		_begin_sol()


func _finish(victory: bool, reason: String) -> void:
	_stop_countdown()
	_set_phase(Phase.ENDED)
	game_ended.emit(victory, {
		"victory": victory,
		"reason": reason,
		"sol": GameState.current_sol,
		"score": GameState.compute_score(),
		"objectives": GameState.objectives_status(),
		"terms_unlocked": GameState.unlocked_terms.size(),
		"terms_total": GlossaryManager.total_terms(),
	})


# ------------------------------------------------------------ Ayuda de la Tierra

func can_request_earth_help() -> bool:
	if phase != Phase.DECISION or GameState.earth_help_used_this_sol or GameState.earth_help_blocked():
		return false
	var kind: String = str(current_event.get("kind", ""))
	if kind == "realtime" or kind == "auto" or current_event.has("timer_seconds"):
		return false
	return current_event.has("earth_hint")


## Pone el evento actual en espera y pasa al siguiente Sol; la pista llega más tarde.
func request_earth_help(choice_id: String) -> bool:
	if not can_request_earth_help():
		return false
	var choice: Dictionary = {}
	for candidate in EARTH_HELP_OPTIONS:
		if candidate["id"] == choice_id:
			choice = candidate
	if choice.is_empty():
		return false

	_stop_countdown()
	GameState.earth_help_used_this_sol = true
	GlossaryManager.unlock("minutos_luz")
	if int(choice["energy_cost"]) > 0:
		GameState.modify_stat("energy", -int(choice["energy_cost"]))
	var return_sol: int = GameState.current_sol + int(choice["delay_sols"])
	_paused_events.append({
		"event": EventManager.get_event(str(current_event["id"])),
		"return_sol": return_sol,
		"hint": str(current_event.get("earth_hint", "")),
	})
	_set_phase(Phase.RESOLUTION)
	earth_help_changed.emit()
	decision_resolved.emit({}, "Message sent to Earth! This problem has to wait. The answer will arrive on Sol %d." % return_sol, true)
	return true


## Sols que faltan para que vuelva cada evento en espera (para la UI).
func waiting_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _paused_events:
		result.append({"title": entry["event"].get("title", "?"), "return_sol": entry["return_sol"]})
	return result


# ---------------------------------------------------------- Evento en tiempo real

## Botón de debug: simula una llamarada M/X. Interrumpe el turno actual.
func simulate_solar_flare() -> void:
	_flare_pending = true
	_flare_triggered = false
	if phase == Phase.DECISION and str(current_event.get("kind", "")) != "realtime":
		_interrupted_event = EventManager.get_event(str(current_event["id"]))
		_stop_countdown()
		var flare: Dictionary = EventManager.get_event(FLARE_EVENT_ID)
		_flare_triggered = true
		_flare_pending = false
		_present_event(flare, "", true)


func _fetch_flare() -> void:
	var start_unix: int = int(Time.get_unix_time_from_system()) - FLARE_LOOKBACK_DAYS * 86400
	var start_date: String = Time.get_date_string_from_unix_time(start_unix)
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	if _http.request(FLARE_URL % [start_date, API_KEY]) != OK:
		push_warning("TurnManager: no se pudo consultar DONKI; sin evento en tiempo real.")


func _on_flare_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (data is Array):
		return
	for flare in data:
		var flare_class: String = str(flare.get("classType", ""))
		if flare_class.begins_with("M") or flare_class.begins_with("X"):
			_flare_info = flare
			_flare_pending = true
			return


# ------------------------------------------------------------------ Cuenta atrás

func _start_countdown(event: Dictionary) -> void:
	if not event.has("timer_seconds"):
		return
	_countdown = float(event["timer_seconds"])
	_last_second = -1
	_countdown_active = true
	set_process(true)


func _stop_countdown() -> void:
	_countdown_active = false
	set_process(false)
	timer_updated.emit(-1)


func _on_countdown_finished() -> void:
	_countdown_active = false
	set_process(false)
	var options: Array = current_event.get("options", [])
	var fallback_id: String = str(options[0]["id"]) if not options.is_empty() else ""
	submit_choice(str(current_event.get("timeout_option", fallback_id)))


# -------------------------------------------------------------------- Utilidades

func _after_state_change() -> Array[String]:
	var lines: Array[String] = []
	if GameState.consume_alert_just_activated():
		EventManager.schedule_event("quake-warned", 1, 2)
		lines.append("The sensor network is complete! It will warn you before a Marsquake.")
	return lines


func _find_option(event: Dictionary, option_id: String) -> Dictionary:
	for option in event.get("options", []):
		if option["id"] == option_id:
			return option
	return {}


func _set_phase(new_phase: int) -> void:
	phase = new_phase
	phase_changed.emit(new_phase)
