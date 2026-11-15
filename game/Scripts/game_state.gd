extends Node
## Autoload "GameState": estado global de la partida (20 Sols).
## Centraliza las variables críticas, el progreso de objetivos, las condiciones
## activas (eventos multi-Sol) y la cola de efectos diferidos.
## No decide qué evento sale ni el orden del turno: eso es de EventManager y TurnManager.

signal stats_changed
signal progress_changed
signal conditions_changed
signal seismic_alert_activated
signal crew_changed

const MAX_SOLS: int = 20
## La ayuda de la Tierra se recarga cada 4 Soles (con 20 Soles salen como mucho 5 ayudas:
## es una pista valiosa, no un botón para cada día). Cuenta desde el Sol en que se pide.
const EARTH_HELP_COOLDOWN_SOLS: int = 4
const ROLES: Array[String] = ["engineer", "biologist", "doctor", "generalist"]
const ROLE_NAMES: Dictionary = {
	"engineer": "Engineer", "biologist": "Biologist", "doctor": "Doctor", "generalist": "Generalist",
}
const STAT_NAMES: Array[String] = ["health", "oxygen", "energy", "integrity"]
const STAT_START: int = 80
const STAT_MAX: int = 100
const HEALTH_GOAL: int = 50

## --- Cambios automáticos de las barras al amanecer de cada Sol ---
## Están elegidos con el simulador de tools/balance_sim.py para que las derrotas de un jugador atento
## se repartan entre las cuatro barras (oxígeno ~19 %, energía ~13 %, salud ~10 %, integridad ~12 %,
## con ~46 % de victorias). Antes casi todas las derrotas eran por oxígeno. Ver docs/juego/diseno.md.
const PASSIVE_OXYGEN_LOSS: int = 3            # hasta que MOXIE esté al 100 %
const PASSIVE_ENERGY_GAIN: int = 7            # paneles solares...
const PASSIVE_ENERGY_GAIN_DUSTY: int = 6      # ...que dan menos cuando se llenan de polvo
const DUSTY_PANELS_FROM_SOL: int = 8
const PASSIVE_INTEGRITY_LOSS: int = 2         # el viento y el polvo desgastan la base
const PASSIVE_HEALTH_LOSS: int = 4            # el estrés y la radiación cansan a la tripulación...
const HEALTH_LOSS_FROM_SOL: int = 4           # ...una vez pasados los primeros Sols
const SEISMIC_DEADLINE_SOL: int = 13
const HARVEST_GOAL: int = 3
const SENSOR_GOAL: int = 3

## Propiedades que un evento puede escribir con "set" / "add" (lista blanca).
const SETTABLE: Array[String] = [
	"sensors_fabricated", "sensors_placed", "moxie_progress", "rover_rescued",
	"quake_happened", "e2_pending", "harvests_completed",
]

# --- Variables críticas (0 a 100) ---
var health: int = STAT_START
var oxygen: int = STAT_START
var energy: int = STAT_START
var integrity: int = STAT_START

# --- Progreso y objetivos ---
var current_sol: int = 1
var harvests_completed: int = 0
var sensors_fabricated: bool = false
var sensors_placed: int = 0
var seismic_alert_active: bool = false
var moxie_progress: int = 0
var rover_rescued: bool = false
var quake_happened: bool = false
var e2_pending: bool = false
var health_always_above_goal: bool = true
var earth_help_ready_sol: int = 1   # primer Sol en que se puede volver a pedir ayuda a la Tierra

## Tripulantes que están fuera de la base: rol -> Sol en que vuelven (ya en la base).
var crew_away: Dictionary = {}

var active_conditions: Array[Dictionary] = []
var unlocked_terms: Array[String] = []
var delayed_queue: DelayedEffectsQueue = DelayedEffectsQueue.new()

var _alert_just_activated: bool = false


func reset() -> void:
	health = STAT_START
	oxygen = STAT_START
	energy = STAT_START
	integrity = STAT_START
	current_sol = 1
	harvests_completed = 0
	sensors_fabricated = false
	sensors_placed = 0
	seismic_alert_active = false
	moxie_progress = 0
	rover_rescued = false
	quake_happened = false
	e2_pending = false
	health_always_above_goal = true
	earth_help_ready_sol = 1
	active_conditions.clear()
	unlocked_terms.clear()
	delayed_queue.clear()
	crew_away.clear()
	_alert_just_activated = false
	crew_changed.emit()
	stats_changed.emit()
	progress_changed.emit()
	conditions_changed.emit()


# --- Recursos ---

## Modificación segura de una variable crítica (siempre entre 0 y 100).
func modify_stat(stat: String, delta: int) -> void:
	if not (stat in STAT_NAMES):
		push_warning("GameState: variable desconocida '%s'." % stat)
		return
	set(stat, clampi(int(get(stat)) + delta, 0, STAT_MAX))
	if stat == "health" and health <= HEALTH_GOAL:
		health_always_above_goal = false
	stats_changed.emit()


func get_stat(stat: String) -> int:
	return int(get(stat)) if stat in STAT_NAMES else 0


# --- Aplicar el resultado de una opción / efecto diferido / condición ---

## Formato del outcome (todas las claves son opcionales):
##   effects: {stat: int}            cambios inmediatos en las barras
##   add:     {prop: int}            suma a un contador de progreso
##   set:     {prop: valor}          fija un valor de progreso o un flag
##   chance:  [{probability, effects, text}]   efectos con probabilidad
##   delayed: [{after_sols, ...outcome...}]    se encolan para un Sol futuro
##   start_condition: {...}          activa una condición multi-Sol
## Devuelve líneas de texto extra para mostrar al jugador.
func apply_outcome(outcome: Dictionary) -> Array[String]:
	var extra_lines: Array[String] = []

	var effects: Dictionary = outcome.get("effects", {})
	for stat in effects:
		modify_stat(str(stat), int(effects[stat]))

	var additions: Dictionary = outcome.get("add", {})
	for prop in additions:
		_add_progress(str(prop), int(additions[prop]))

	var settings: Dictionary = outcome.get("set", {})
	for prop in settings:
		_set_progress(str(prop), settings[prop])

	for roll in outcome.get("chance", []):
		if randf() <= float(roll.get("probability", 0.0)):
			var roll_effects: Dictionary = roll.get("effects", {})
			for stat in roll_effects:
				modify_stat(str(stat), int(roll_effects[stat]))
			var roll_text: String = roll.get("text", "")
			if not roll_text.is_empty():
				extra_lines.append(roll_text)

	for delayed in outcome.get("delayed", []):
		delayed_queue.enqueue(current_sol + int(delayed.get("after_sols", 1)), delayed)

	if outcome.has("start_condition"):
		start_condition(outcome["start_condition"])

	if outcome.has("away_all"):
		send_all_away(int(outcome["away_all"]), true)  # solo se usa en efectos diferidos (al amanecer)

	_refresh_seismic_alert()
	progress_changed.emit()
	return extra_lines


## Resultado de una opción que FALLA: se pagan todos los costes (efectos negativos),
## se pierden las ganancias, el progreso y los efectos diferidos, y se aplica el
## castigo opcional "on_fail" (mismo formato que un outcome). Devuelve líneas extra.
func apply_failure(option: Dictionary) -> Array[String]:
	var costs: Dictionary = {}
	var effects: Dictionary = option.get("effects", {})
	for stat in effects:
		if int(effects[stat]) < 0:
			costs[stat] = int(effects[stat])
	var lines: Array[String] = apply_outcome({"effects": costs})
	lines.append_array(apply_outcome(option.get("on_fail", {})))
	return lines


func _add_progress(prop: String, amount: int) -> void:
	if not (prop in SETTABLE):
		push_warning("GameState: no se puede modificar '%s'." % prop)
		return
	set(prop, maxi(0, int(get(prop)) + amount))


func _set_progress(prop: String, value: Variant) -> void:
	if not (prop in SETTABLE):
		push_warning("GameState: no se puede modificar '%s'." % prop)
		return
	# JSON entrega los números como float: los convertimos al tipo de la variable.
	if get(prop) is int:
		set(prop, int(value))
	else:
		set(prop, value)


func _refresh_seismic_alert() -> void:
	if sensors_placed >= SENSOR_GOAL and not seismic_alert_active and current_sol < SEISMIC_DEADLINE_SOL:
		seismic_alert_active = true
		_alert_just_activated = true
		seismic_alert_activated.emit()
	elif sensors_placed < SENSOR_GOAL and seismic_alert_active:
		seismic_alert_active = false


## True una sola vez tras activarse la alerta sísmica (TurnManager programa el aviso).
func consume_alert_just_activated() -> bool:
	var result: bool = _alert_just_activated
	_alert_just_activated = false
	return result


# --- Tripulación fuera de la base ---

func is_away(role: String) -> bool:
	return crew_away.has(role)


## Soles completos que le faltan para volver (0 si está en la base).
func away_sols_left(role: String) -> int:
	return maxi(int(crew_away.get(role, current_sol)) - current_sol, 0)


## Tripulantes que ahora mismo están en la base.
func available_crew() -> Array[String]:
	var present: Array[String] = []
	for role in ROLES:
		if not is_away(role):
			present.append(role)
	return present


## Deja a un tripulante ocupado `sols` Soles (docs/juego/tiempos_fuera.md): no está disponible
## durante los `sols` Soles siguientes y vuelve al empezar el que va después.
## Con sols = 1: no está mañana y vuelve pasado mañana.
## `starts_today` = true para efectos diferidos, que se aplican al amanecer: el tripulante
## está ocupado ese mismo Sol (así "ocupa a todos mañana" deja la base vacía mañana).
func send_away(role: String, sols: int, starts_today: bool = false) -> void:
	if not (role in ROLES) or sols <= 0:
		return
	crew_away[role] = current_sol + sols + (0 if starts_today else 1)
	crew_changed.emit()


## Salida grupal (EVA): toda la tripulación queda ocupada y la base se queda vacía.
func send_all_away(sols: int, starts_today: bool = false) -> void:
	for role in ROLES:
		send_away(role, sols, starts_today)


## True si no queda nadie en la base (los 4 están ocupados).
func base_is_empty() -> bool:
	return available_crew().is_empty()


## Al empezar un Sol vuelven los que ya han cumplido su tiempo. Devuelve líneas de aviso.
func process_crew_return() -> Array[String]:
	var lines: Array[String] = []
	for role in crew_away.keys():
		if current_sol >= int(crew_away[role]):
			crew_away.erase(role)
			lines.append("The %s is back at the base!" % ROLE_NAMES[role])
	if not lines.is_empty():
		crew_changed.emit()
	return lines


# --- Condiciones multi-Sol ---

## Una condición: {id, name, sols, daily?, sequence?, blocks_earth_help?, on_end?}
func start_condition(definition: Dictionary) -> void:
	var condition: Dictionary = definition.duplicate(true)
	condition["sols_left"] = int(definition.get("sols", 1))
	condition["step"] = 0
	for i in range(active_conditions.size()):
		if active_conditions[i]["id"] == condition["id"]:
			active_conditions[i] = condition  # refresca en vez de duplicar
			conditions_changed.emit()
			return
	active_conditions.append(condition)
	conditions_changed.emit()


func is_condition_active(condition_id: String) -> bool:
	for condition in active_conditions:
		if condition["id"] == condition_id:
			return true
	return false


## Soles que faltan para poder volver a pedir ayuda a la Tierra (0 = ya se puede).
func earth_help_cooldown_left() -> int:
	return maxi(0, earth_help_ready_sol - current_sol)


func earth_help_blocked() -> bool:
	for condition in active_conditions:
		if condition.get("blocks_earth_help", false):
			return true
	return false


## Aplica el efecto de cada condición activa y resta un Sol. Devuelve líneas de resumen.
func process_conditions() -> Array[String]:
	var lines: Array[String] = []
	var remaining: Array[Dictionary] = []
	for condition in active_conditions:
		var daily: Dictionary = {}
		if condition.has("sequence"):
			var sequence: Array = condition["sequence"]
			var step: int = int(condition["step"])
			if step < sequence.size():
				daily = sequence[step]
		else:
			daily = condition.get("daily", {})
		if not daily.is_empty():
			apply_outcome({"effects": daily})
			lines.append("%s is still hurting the base this morning." % condition.get("name", condition["id"]))
		condition["step"] = int(condition["step"]) + 1
		condition["sols_left"] = int(condition["sols_left"]) - 1
		if int(condition["sols_left"]) > 0:
			remaining.append(condition)
		else:
			lines.append("%s is over!" % condition.get("name", condition["id"]))
			if condition.has("on_end"):
				apply_outcome(condition["on_end"])
	active_conditions = remaining
	conditions_changed.emit()
	return lines


# --- Efectos diferidos ---

## Aplica los efectos diferidos que vencen en el Sol actual. Devuelve sus textos.
func process_delayed_effects() -> Array[String]:
	var lines: Array[String] = []
	for outcome in delayed_queue.pop_due(current_sol):
		lines.append_array(apply_outcome(outcome))
		var text: String = outcome.get("text", "")
		if not text.is_empty():
			lines.append(text)
	return lines


# --- Consumo pasivo ---

func passive_oxygen_loss() -> int:
	return 0 if moxie_progress >= 100 else PASSIVE_OXYGEN_LOSS


func passive_energy_gain() -> int:
	return PASSIVE_ENERGY_GAIN_DUSTY if current_sol >= DUSTY_PANELS_FROM_SOL else PASSIVE_ENERGY_GAIN


func passive_integrity_loss() -> int:
	return PASSIVE_INTEGRITY_LOSS


func passive_health_loss() -> int:
	return PASSIVE_HEALTH_LOSS if current_sol >= HEALTH_LOSS_FROM_SOL else 0


# --- Fin de partida y objetivos ---

## "" si la partida continúa; "defeat:<variable>" o "victory" si termina.
func check_end() -> String:
	for stat in STAT_NAMES:
		if get_stat(stat) <= 0:
			return "defeat:" + stat
	if current_sol >= MAX_SOLS:
		return "victory"
	return ""


func objectives_status() -> Dictionary:
	return {
		"health": health_always_above_goal,
		"colony": harvests_completed >= HARVEST_GOAL,
		"rover": rover_rescued,
		"sensors": sensors_placed >= SENSOR_GOAL,
		"moxie": moxie_progress >= 100,
	}


func objectives_completed() -> int:
	var count: int = 0
	for done in objectives_status().values():
		if done:
			count += 1
	return count


## Puntuación final: 200 por objetivo + media de las barras.
func compute_score() -> int:
	var average: int = int((health + oxygen + energy + integrity) / 4.0)
	return objectives_completed() * 200 + average
