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
signal reading_finished   ## Ya se leyó el evento: se pueden elegir opciones (y empieza la cuenta atrás, si la hay).
signal game_ended(victory: bool, report: Dictionary)
## Cambió el recuento de la votación de los móviles (alguien votó, empate, se fue un votante…).
signal votes_changed

const FLARE_URL: String = "https://api.nasa.gov/DONKI/FLR?startDate=%s&api_key=%s"
const API_KEY: String = "DEMO_KEY"  # límite bajo: usar una key gratuita de api.nasa.gov en la demo
const FLARE_EVENT_ID: String = "rt-solar-flare"
const REQUEST_TIMEOUT: float = 3.0

## Lectura del evento: el texto sale poco a poco y no se puede elegir hasta que acaba, para que
## se lea antes de pulsar. 23 letras por segundo se nota que va escribiendo pero deja leer sin esperar de
## más: un texto normal (~130 letras) tarda unos 6 s. Mínimo y máximo para que nunca sea eterno ni instantáneo.
const READING_CHARS_PER_SECOND: float = 23.0
const READING_MIN_SECONDS: float = 2.5
const READING_MAX_SECONDS: float = 12.0
const FLARE_LOOKBACK_DAYS: int = 3

## Distancia Tierra-Marte de respaldo (no se consulta JPL Horizons en este prototipo).
const EARTH_DISTANCE_MILLION_KM: int = 225
const EARTH_SIGNAL_MINUTES: int = 12

## Formas de pedir ayuda a la Tierra. La ventana (EarthPanel) enseña el título, el texto, el coste y la espera.
const EARTH_HELP_OPTIONS: Array[Dictionary] = [
	{"id": "full-report", "title": "Full report", "text": "The Commander tells Earth everything.",
		"energy_cost": 5, "delay_sols": 1},
	{"id": "quick-message", "title": "Quick message", "text": "A short note. The answer is slower.",
		"energy_cost": 0, "delay_sols": 2},
]

var phase: int = Phase.IDLE
var current_event: Dictionary = {}
var current_event_uid: String = ""   # "<id>#<n>": identifica ESTA aparición del evento (para los móviles)

var reading: bool = false              # true mientras el texto del evento sale; aún no se puede decidir
var reading_seconds: float = 0.0       # lo que dura esa lectura (la pantalla escribe el texto en este tiempo)

var _reading_token: int = 0
var _event_counter: int = 0

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
	_event_counter = 0
	_clear_votes()
	_paused_events.clear()
	_interrupted_event = {}
	_flare_triggered = false
	_first_sol = true
	GlossaryManager.unlock("sol")
	Events.sfx_requested.emit("rocket_landing", 0.0)  # la misión empieza con el aterrizaje
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
		var returned: Array[String] = GameState.process_crew_return()
		if not returned.is_empty():
			Events.sfx_requested.emit("door", 0.0)  # alguien vuelve a entrar en la base
		lines.append_array(returned)
		var loss: int = GameState.passive_oxygen_loss()
		if loss > 0:
			GameState.modify_stat("oxygen", -loss)
			lines.append("Everyone breathed: Oxygen -%d." % loss)
		var gain: int = GameState.passive_energy_gain()
		GameState.modify_stat("energy", gain)
		if gain < GameState.PASSIVE_ENERGY_GAIN:
			lines.append("The solar panels are dusty and made less power: Energy +%d." % gain)
		else:
			lines.append("Sunshine! The solar panels made Energy +%d." % gain)
		var wear: int = GameState.passive_integrity_loss()
		if wear > 0:
			GameState.modify_stat("integrity", -wear)
			lines.append("Wind and dust wore down the base: Base strength -%d." % wear)
		var stress: int = GameState.passive_health_loss()
		if stress > 0:
			GameState.modify_stat("health", -stress)
			lines.append("Living far from home is tiring: Health -%d." % stress)
		lines.append_array(GameState.process_conditions())
		lines.append_array(GameState.process_delayed_effects())
		lines.append_array(_after_state_change())
	earth_help_changed.emit()
	sol_started.emit(GameState.current_sol, lines)
	if GameState.check_end().begins_with("defeat"):
		_finish(false, GameState.check_end())
		return
	if GameState.base_is_empty():
		_empty_base_day()
		return
	_select_event()


## Regla de base vacía: si los 4 tripulantes están ocupados no hay nadie para gestionar
## problemas, así que ese Sol no sale ningún evento. El consumo diario ya se ha aplicado
## al amanecer; solo hay que avisar y dejar pasar el día.
func _empty_base_day() -> void:
	var back_sol: int = 1 << 30
	for role in GameState.crew_away:
		back_sol = mini(back_sol, int(GameState.crew_away[role]))
	_event_counter += 1
	current_event = {
		"id": "empty-base",
		"title": "The base is empty!",
		"description": "The whole crew is busy outside, so nobody is home to handle problems today. Nothing new happens and the day just passes.",
		"nasa_fact": "",
		"terms": [],
		"options": [],
		"scene": {"effect": "none"},
	}
	current_event_uid = "empty-base#%d" % _event_counter
	_set_phase(Phase.RESOLUTION)
	earth_help_changed.emit()
	event_presented.emit(current_event, "")
	decision_resolved.emit({}, "No event today. The crew will be back on Sol %d." % back_sol, true)


# ------------------------------------------------------- FASE_SELECCION_EVENTO

func _select_event() -> void:
	_set_phase(Phase.EVENT_SELECTION)
	var event: Dictionary = {}
	var hint: String = ""
	var fresh: bool = true

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
			fresh = entry.get("fresh", true)  # false: ya se aplicaron sus efectos de inicio
			if not hint.is_empty():
				Events.sfx_requested.emit("intercom", 0.0)  # llega la respuesta de la Tierra

	if event.is_empty():
		event = EventManager.pick_event()

	if event.is_empty():
		push_error("TurnManager: no event available on Sol %d." % GameState.current_sol)
		_end_sol()
		return
	_present_event(event, hint, fresh)


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
	_clear_votes()
	_event_counter += 1
	current_event_uid = "%s#%d" % [event["id"], _event_counter]

	if fresh:
		EventManager.mark_seen(str(event["id"]))
		GlossaryManager.unlock_many(event.get("terms", []))
		if event.has("on_start"):
			GameState.apply_outcome(event["on_start"])
			if GameState.check_end().begins_with("defeat"):
				_finish(false, GameState.check_end())
				return

	_set_phase(Phase.DECISION)
	_begin_reading(shown)
	earth_help_changed.emit()
	event_presented.emit(shown, hint)
	if not _has_available_option(shown):
		_defer_until_crew_returns(event)
		return
	get_tree().create_timer(reading_seconds).timeout.connect(_on_reading_timeout.bind(_reading_token))


## Tiempo que se da para leer un evento según lo largo que es su texto.
func reading_seconds_for(event: Dictionary) -> float:
	var length: int = str(event.get("description", "")).length()
	return clampf(float(length) / READING_CHARS_PER_SECOND, READING_MIN_SECONDS, READING_MAX_SECONDS)


func _begin_reading(event: Dictionary) -> void:
	reading = true
	reading_seconds = reading_seconds_for(event)
	_reading_token += 1


## Acabó el tiempo de lectura (si el evento sigue siendo el mismo): ya se puede decidir.
func _on_reading_timeout(token: int) -> void:
	if token != _reading_token or not reading or phase != Phase.DECISION:
		return
	reading = false
	reading_finished.emit()
	earth_help_changed.emit()
	_start_countdown(current_event)


# ------------------------------------------- Tripulación fuera: opciones bloqueadas

## Por qué una opción no se puede elegir ahora ("" si se puede).
## - Una opción de un rol no se puede elegir si ese tripulante está ocupado.
## - Una salida grupal ("para todos" con ocupación) necesita a toda la tripulación en la base.
func option_block_reason(option: Dictionary) -> String:
	var role: Variant = option.get("role")
	if role != null:
		var role_id: String = str(role)
		role_id = _effective_crew_role(role_id)
		if GameState.is_away(role_id):
			var sols_left: int = GameState.away_sols_left(role_id)
			return "The %s is busy (back in %d Sol%s)." % [
				GameState.ROLE_NAMES[role_id], sols_left, "" if sols_left == 1 else "s"]
		return ""
	if int(option.get("away_sols", 0)) > 0 and GameState.available_crew().size() < GameState.ROLES.size():
		return "The whole crew must be at the base to go out together."
	return ""


func _has_available_option(event: Dictionary) -> bool:
	for option in event.get("options", []):
		if option_block_reason(option).is_empty() and _someone_can_vote():
			return true
	return false


## Con móviles: ¿queda algún jugador presente y en la base que pueda votar?
## (Si todos los jugadores están ocupados fuera, el evento espera a que vuelva alguien.)
func _someone_can_vote() -> bool:
	if present_roles.is_empty():
		return true
	for role in present_roles:
		if not GameState.is_away(role):
			return true
	return false


## Si no se puede elegir ninguna opción, el problema espera hasta que vuelva alguien.
## Se guarda como evento en espera (sin repetir sus efectos de inicio).
func _defer_until_crew_returns(event: Dictionary) -> void:
	var return_sol: int = GameState.current_sol + 1
	if not GameState.crew_away.is_empty():
		return_sol = 1 << 30
		for role in GameState.crew_away:
			return_sol = mini(return_sol, int(GameState.crew_away[role]))
	_paused_events.append({
		"event": EventManager.get_event(str(event["id"])),
		"return_sol": return_sol,
		"hint": "",
		"fresh": false,
	})
	_stop_countdown()
	_set_phase(Phase.RESOLUTION)
	earth_help_changed.emit()
	decision_resolved.emit({}, "Everyone who could help is busy! The problem waits until someone is back (Sol %d)." % return_sol, true)


# ---------------------------------------------------------- Opciones para los móviles

## Roles que tienen jugador en la sala. Vacío = partida local en una sola pantalla (los 4 roles).
## Todos los jugadores ven y pueden votar TODAS las opciones, sean de su rol o no: si solo votara
## el dueño del rol, casi nunca saldría elegida su opción. Así tampoco hay decisiones que dependan
## de un rol ausente (se puede jugar con 1-4 jugadores).
var present_roles: Array[String] = []
## Roles con el móvil conectado ahora mismo. Solo votan estos (un móvil caído no bloquea la votación).
var connected_roles: Array[String] = []

# Votación de los móviles (docs/juego/diseno.md, docs/godot/red.md):
# cada jugador presente vota una opción; cuando han votado todos los que pueden, gana la más votada.
# Empate -> segunda votación solo entre las empatadas; si vuelve a empatar, decide el Comandante.
var _votes: Dictionary = {}               # role -> option_id
var _tie_options: Array[String] = []      # en el desempate, las únicas opciones que se pueden votar
var commander_role: String = ""

func _effective_crew_role(role_id: String) -> String:
	return role_id


## Roles que tienen que votar en el evento actual: conectados, en la base y con alguna opción libre.
func voters() -> Array[String]:
	var result: Array[String] = []
	if phase != Phase.DECISION:
		return result
	for role in connected_roles:
		if GameState.is_away(role):
			continue
		for option in options_for_role(role):
			if not bool(option["disabled"]):
				result.append(role)
				break
	return result


func votes() -> Dictionary:
	return _votes


## Opciones empatadas que se están desempatando ([] si no hay empate).
func tie_options() -> Array[String]:
	return _tie_options


## La sala avisa de quién tiene el móvil conectado. Si se va alguien que faltaba por votar,
## puede que ya hayan votado todos los demás.
func set_connected_roles(roles: Array[String]) -> void:
	connected_roles = roles
	if phase == Phase.DECISION and not _votes.is_empty() and not _try_resolve_votes():
		votes_changed.emit()


func set_commander_role(role: String) -> void:
	commander_role = role


## Voto de un móvil. Devuelve "" si se acepta o el motivo del rechazo (choice_result).
## Con el último voto que faltaba se resuelve el evento (o empieza el desempate).
func cast_vote(role: String, event_uid: String, option_id: String) -> String:
	var reason: String = choice_reject_reason(role, event_uid, option_id)
	if not reason.is_empty():
		return reason
	_votes[role] = option_id
	if not _try_resolve_votes():
		votes_changed.emit()
	return ""


func _clear_votes() -> void:
	_votes.clear()
	_tie_options.clear()


## true si la votación terminó (resuelta o empieza el desempate): ya se avisó a todos.
func _try_resolve_votes() -> bool:
	if phase != Phase.DECISION:
		return false
	var needed: Array[String] = voters()
	if needed.is_empty():
		return false
	for role in needed:
		if not _votes.has(role):
			return false
	var winners: Array[String] = _most_voted()
	if winners.size() == 1:
		submit_choice(winners[0])
	elif _tie_options.is_empty():
		_start_tiebreak(winners)
	else:
		var commander_vote: String = str(_votes.get(commander_role, ""))
		var decided_option: String = commander_vote if commander_vote in winners else winners[0]
		submit_choice(decided_option, "It was a tie again, so the Commander's vote decided!")
	return true


## Opciones con más votos, en el orden del evento.
func _most_voted() -> Array[String]:
	var counts: Dictionary = {}
	for option_id in _votes.values():
		counts[option_id] = int(counts.get(option_id, 0)) + 1
	var best: int = 0
	for count in counts.values():
		best = maxi(best, int(count))
	var result: Array[String] = []
	for option in current_event.get("options", []):
		if int(counts.get(option["id"], 0)) == best and best > 0:
			result.append(str(option["id"]))
	return result


## Primer empate: se vota otra vez solo entre las empatadas. El evento no cambia, pero sí su
## eventId, para que un voto de la ronda anterior que llegue tarde se rechace (event_closed).
func _start_tiebreak(tied: Array[String]) -> void:
	_votes.clear()
	_tie_options = tied
	current_event_uid = "%s#%d-tie" % [current_event["id"], _event_counter]
	var labels: PackedStringArray = []
	for option_id in tied:
		labels.append(str(_find_option(current_event, option_id).get("label", option_id)))
	Events.sfx_requested.emit("intercom", 0.0)
	event_presented.emit(current_event, "It's a tie! Vote again between: %s." % ", ".join(labels))
	votes_changed.emit()


## Opciones que ve el jugador de `role` en el evento actual, con su estado: TODAS las del evento
## (se puede votar una opción de otro rol). Las que tienen un rol dueño llevan su nombre delante,
## para saber quién la haría y quién quedará ocupado. `id` y `label` son los del contrato
## (docs/protocol.md); `detail` (costes), `disabled` y `reason` son campos opcionales del mismo contrato.
func options_for_role(_role: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for option in current_event.get("options", []):
		if not _tie_options.is_empty() and not (str(option["id"]) in _tie_options):
			continue
		var reason: String = option_block_reason(option)
		var label: String = str(option["label"])
		var option_role: Variant = option.get("role")
		if option_role != null:
			label = "(%s) %s" % [GameState.ROLE_NAMES[str(option_role)], label]
		result.append({
			"id": str(option["id"]),
			"label": label,
			"detail": OptionInfo.costs_text(option),
			"disabled": not reason.is_empty(),
			"reason": reason,
		})
	return result


## Vista (controller_view) que debe mostrar el móvil del jugador con ese rol.
func controller_view_for(role: String) -> Dictionary:
	if GameState.is_away(role):
		var sols_left: int = GameState.away_sols_left(role)
		return {"screen": "waiting", "title": "You are busy!",
			"text": "You are back in %d Sol%s." % [sols_left, "" if sols_left == 1 else "s"]}
	if phase != Phase.DECISION:
		return {"screen": "waiting", "title": "Waiting for the crew...", "text": "Look at the main screen."}
	if reading:
		return {"screen": "waiting", "title": "Read the story!",
			"text": "Look at the main screen. Your options will appear in a moment."}
	if _votes.has(role):
		var chosen: Dictionary = _find_option(current_event, str(_votes[role]))
		return {"screen": "waiting", "title": "Vote sent!",
			"text": "You voted: %s\n%s" % [chosen.get("label", ""), vote_progress_text()]}
	return {
		"screen": "choice",
		"eventId": current_event_uid,
		"title": str(current_event.get("title", "")),
		"prompt": "What will you do?",
		"options": options_for_role(role),
	}


## Por qué no se acepta una elección de un móvil ("" si es válida). Los motivos son los de
## `choice_result` del contrato: event_closed, not_eligible, invalid_option.
func choice_reject_reason(role: String, event_uid: String, option_id: String) -> String:
	if event_uid != current_event_uid or phase != Phase.DECISION or reading:
		return "event_closed"   # (si aún se está leyendo, tampoco se acepta nada)
	if GameState.is_away(role):
		return "not_eligible"
	if _votes.has(role):
		return "already_decided"
	var option: Dictionary = _find_option(current_event, option_id)
	if option.is_empty() or not option_block_reason(option).is_empty():
		return "invalid_option"
	if not _tie_options.is_empty() and not (option_id in _tie_options):
		return "invalid_option"
	return ""


## «2 of 3 have voted.» (para el móvil y la pantalla principal).
func vote_progress_text() -> String:
	var needed: Array[String] = voters()
	var done: int = 0
	for role in needed:
		if _votes.has(role):
			done += 1
	return "%d of %d have voted." % [done, needed.size()]


## Elección directa (pantalla principal: partida sin móviles o simulador de debug) o resultado de
## la votación de los móviles (cast_vote). `note` es una línea que va antes del resultado.
func submit_choice(option_id: String, note: String = "") -> bool:
	if phase != Phase.DECISION or reading:
		return false
	var option: Dictionary = _find_option(current_event, option_id)
	if option.is_empty() or not option_block_reason(option).is_empty():
		return false
	_clear_votes()
	_stop_countdown()

	# ---- FASE_RESOLUCION ----
	_set_phase(Phase.RESOLUTION)
	# Cada opción puede fallar ("success_chance", 1.0 si no se indica).
	var success: bool = randf() <= float(option.get("success_chance", 1.0))
	var lines: Array[String] = []
	if not note.is_empty():
		lines.append(note)
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
	# La tarea deja ocupado a quien la hace (haya salido bien o mal): el rol de la opción o,
	# si es una salida de todos, toda la tripulación. Ver docs/juego/tiempos_fuera.md.
	var busy_sols: int = int(option.get("away_sols", 0))
	if busy_sols > 0:
		var plural: String = "" if busy_sols == 1 else "s"
		if option.get("role") != null:
			var worker: String = _effective_crew_role(str(option["role"]))
			GameState.send_away(worker, busy_sols)
			lines.append("The %s will be busy for %d Sol%s." % [GameState.ROLE_NAMES[worker], busy_sols, plural])
		else:
			GameState.send_all_away(busy_sols)
			lines.append("The whole crew goes out together! The base will be empty for %d Sol%s." % [busy_sols, plural])
	lines.append_array(_after_state_change())
	Events.sfx_requested.emit("success" if success else "failure", 0.0)
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
	if phase != Phase.DECISION or reading or GameState.earth_help_cooldown_left() > 0 or GameState.earth_help_blocked():
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
	GameState.earth_help_ready_sol = GameState.current_sol + GameState.EARTH_HELP_COOLDOWN_SOLS
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
	# Si ya hay votos, gana la más votada (en empate, la opción por defecto si está entre ellas).
	var winners: Array[String] = _most_voted()
	if not winners.is_empty():
		var fallback: String = str(current_event.get("timeout_option", ""))
		submit_choice(fallback if fallback in winners else winners[0])
		return
	# Al acabar el tiempo se elige la opción por defecto; si está bloqueada, la primera libre.
	var chosen_id: String = str(current_event.get("timeout_option", ""))
	var default_option: Dictionary = _find_option(current_event, chosen_id)
	if default_option.is_empty() or not option_block_reason(default_option).is_empty():
		chosen_id = ""
		for option in current_event.get("options", []):
			if option_block_reason(option).is_empty():
				chosen_id = str(option["id"])
				break
	submit_choice(chosen_id)


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
	if new_phase != Phase.DECISION:
		reading = false      # fuera de la decisión no hay nada que leer
		_reading_token += 1
	phase = new_phase
	phase_changed.emit(new_phase)
