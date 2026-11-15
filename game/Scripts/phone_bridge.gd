extends Node
## Autoload "PhoneBridge": une el juego (TurnManager) con los móviles a través de Net.
##
## Godot es la autoridad del juego: aquí se decide qué ve cada móvil y se VALIDA cada elección
## que llega (evento vigente, jugador y opción válidos, duplicados). El móvil solo envía `optionId`.
##
##   TurnManager --event_presented--> PhoneBridge --controller_view--> Net --> móvil
##   móvil --choose--> Net --> PhoneBridge --valida--> choice_result + TurnManager.cast_vote
##
## Cada jugador vota; TurnManager resuelve cuando han votado todos los que pueden (o desempata).
##
## Si no hay sala abierta (`active == false`) el juego funciona igual en una sola pantalla.
## Contrato: docs/protocol.md. Guía: docs/godot/red.md.

signal session_changed   ## Empieza o termina una partida con móviles.

const RESULT_MEMORY: int = 200   ## Cuántos actionId recientes se recuerdan (idempotencia).

var active: bool = false             ## Hay una partida en marcha con móviles.
var players: Array = []              ## [{id, name, role, connected}] de `game_started` / `lobby_state`

var _results: Dictionary = {}        ## actionId -> {accepted: bool, reason: String}
var _result_order: Array[String] = []
var _last_result_view: Dictionary = {}
var _continue_votes: Dictionary = {} ## playerId -> actionId
var _continue_actions: Dictionary = {} ## actionId -> playerId


func _ready() -> void:
	Events.game_started.connect(_on_game_started)
	Events.lobby_updated.connect(_on_lobby_updated)
	Events.player_choice_received.connect(_on_choice)
	Events.player_continue_received.connect(_on_continue)
	Events.net_disconnected.connect(_on_net_disconnected)
	TurnManager.event_presented.connect(_on_event_presented)
	TurnManager.decision_resolved.connect(_on_decision_resolved)
	TurnManager.game_ended.connect(_on_game_ended)
	TurnManager.votes_changed.connect(_on_votes_changed)


## Roles de los jugadores de la sala (sin repetir). Con `only_connected`, solo los que tienen el móvil conectado.
func roles(only_connected: bool = false) -> Array[String]:
	var result: Array[String] = []
	for player in players:
		if only_connected and not bool(player.get("connected", true)):
			continue
		var role: Variant = player.get("role")
		if role != null and not (str(role) in result):
			result.append(str(role))
	return result


## Se llama al volver al menú: cierra la sala (la partida terminó o se abandonó).
func end_session() -> void:
	if Net.is_open():
		if active:
			Net.finish_game()   # los mandos reciben room_closed "game_finished"
		else:
			Net.close()
	_reset()


## Partida en una sola pantalla: sin móviles.
func use_local_only() -> void:
	if Net.is_open() or Net.is_connecting():
		Net.close()
	_reset()


func _reset() -> void:
	var was_active: bool = active
	active = false
	players = []
	_results.clear()
	_result_order.clear()
	_continue_votes.clear()
	_continue_actions.clear()
	TurnManager.present_roles = []
	TurnManager.connected_roles = []
	TurnManager.set_commander_role("")
	if was_active:
		session_changed.emit()


# ---------------------------------------------------------------- Sala y jugadores

func _on_game_started(started_players: Array) -> void:
	_results.clear()
	_result_order.clear()
	players = started_players
	active = true
	_continue_votes.clear()
	_continue_actions.clear()
	TurnManager.present_roles = roles()
	TurnManager.set_commander_role(_commander_role())
	TurnManager.set_connected_roles(roles(true))
	if TurnManager.phase == TurnManager.Phase.RESOLUTION:
		_try_continue()
	session_changed.emit()
	for player in players:
		_send(player, {
			"screen": "waiting", "title": "Get ready!",
			"text": "The mission is about to start. Look at the main screen.",
		})


func _on_lobby_updated(updated_players: Array, _status: String) -> void:
	if not active:
		return
	# Un móvil que vuelve a conectarse recibe lo vigente (si el evento se resolvió mientras estaba fuera).
	for updated in updated_players:
		if not bool(updated.get("connected", false)):
			continue
		for previous in players:
			if previous.get("id") == updated.get("id") and not bool(previous.get("connected", false)):
				_send(updated, _current_view(str(updated.get("role", ""))))
	players = updated_players
	TurnManager.set_connected_roles(roles(true))
	if TurnManager.phase == TurnManager.Phase.RESOLUTION:
		_try_continue()


func _commander_role() -> String:
	for player in players:
		if bool(player.get("commander", false)):
			return str(player.get("role", ""))
	return ""


func _on_net_disconnected() -> void:
	# El anfitrión no se recupera: la sala ya no existe y los mandos han recibido room_closed.
	if active:
		push_warning("PhoneBridge: se perdió la conexión con el backend; la partida sigue en esta pantalla.")
	_reset()


# ---------------------------------------------------------------- Juego -> móviles

func _on_event_presented(_event: Dictionary, _hint: String) -> void:
	if not active:
		return
	for player in players:
		_send(player, _current_view(str(player.get("role", ""))))


func _on_decision_resolved(option: Dictionary, feedback: String, success: bool) -> void:
	if not active:
		return
	_last_result_view = {
		"screen": "result",
		"canContinue": true,
		# Sin opción = no se decidió nada (el problema espera, se pidió ayuda a la Tierra…).
		"title": "News from the base" if option.is_empty() else ("It worked!" if success else "Oh no!"),
		"text": feedback,
	}
	for player in players:
		_send(player, _last_result_view)
	_continue_votes.clear()
	_continue_actions.clear()


func _on_game_ended(victory: bool, report: Dictionary) -> void:
	if not active:
		return
	var view: Dictionary = {
		"screen": "result",
		"canContinue": false,
		"title": "Mission complete!" if victory else "Mission failed",
		"text": "Final score: %d. Look at the main screen." % int(report.get("score", 0)),
	}
	for player in players:
		_send(player, view)


func _on_continue(player_id: String, _role: String, action_id: String) -> void:
	if not active or TurnManager.phase != TurnManager.Phase.RESOLUTION:
		return
	if not _is_player(player_id) or action_id.is_empty() or _continue_actions.has(action_id):
		return
	_continue_actions[action_id] = player_id
	_continue_votes[player_id] = action_id
	for player in players:
		if str(player.get("id", "")) == player_id:
			_send(player, {
				"screen": "waiting", "title": "Ready to continue",
				"text": "Waiting for the rest of the crew…",
			})
			break
	_try_continue()


func _try_continue() -> void:
	for player in players:
		if bool(player.get("connected", false)) and not _continue_votes.has(str(player.get("id", ""))):
			return
	_continue_votes.clear()
	_continue_actions.clear()
	TurnManager.continue_after_resolution()


## Lo que debe ver ahora el móvil de un rol: la pregunta si hay decisión, si no la última noticia.
func _current_view(role: String) -> Dictionary:
	if TurnManager.phase == TurnManager.Phase.RESOLUTION and not _last_result_view.is_empty() \
			and not GameState.is_away(role):
		return _last_result_view
	return TurnManager.controller_view_for(role)


func _send(player: Dictionary, view: Dictionary) -> void:
	if Net.is_open():
		Net.send_view(str(player.get("id", "")), view)


# ---------------------------------------------------------------- Móviles -> juego

## Valida una elección en el orden de docs/godot/red.md y la aplica si es correcta.
func _on_choice(player_id: String, role: String, action_id: String, event_id: String, option_id: String) -> void:
	if not active:
		Net.send_result(player_id, action_id, false, "event_closed")
		return

	# 1. Duplicado (mismo actionId): misma respuesta, SIN repetir efectos.
	if _results.has(action_id):
		var previous: Dictionary = _results[action_id]
		Net.send_result(player_id, action_id, bool(previous["accepted"]), str(previous["reason"]))
		return

	# 2. ¿El jugador existe en la partida? (la identidad la garantiza Node)
	if not _is_player(player_id):
		_reject(player_id, action_id, "not_eligible")
		return

	# 3. Evento vigente, rol libre y opción válida.
	var reason: String = TurnManager.choice_reject_reason(role, event_id, option_id)
	if not reason.is_empty():
		_reject(player_id, action_id, reason)
		return

	# 4. Aceptar el voto. Con el último que faltaba, TurnManager resuelve y todos reciben el resultado;
	#    si no, votes_changed manda a quien ya votó su pantalla de espera con el recuento.
	_remember(action_id, true, "")
	Net.send_result(player_id, action_id, true)
	TurnManager.cast_vote(role, event_id, option_id)


## Alguien votó o se fue un votante: quien ya votó ve «Vote sent!» con el recuento actualizado.
func _on_votes_changed() -> void:
	if not active or TurnManager.phase != TurnManager.Phase.DECISION:
		return
	var voted: Dictionary = TurnManager.votes()
	for player in players:
		var role: String = str(player.get("role", ""))
		if voted.has(role):
			_send(player, _current_view(role))


func _is_player(player_id: String) -> bool:
	for player in players:
		if str(player.get("id", "")) == player_id:
			return true
	return false


func _reject(player_id: String, action_id: String, reason: String) -> void:
	_remember(action_id, false, reason)
	Net.send_result(player_id, action_id, false, reason)
	# El móvil se queda con la pantalla que tenía: se le manda la vista vigente por si estaba desfasado.
	for player in players:
		if str(player.get("id", "")) == player_id:
			_send(player, _current_view(str(player.get("role", ""))))


func _remember(action_id: String, accepted: bool, reason: String) -> void:
	_results[action_id] = {"accepted": accepted, "reason": reason}
	_result_order.append(action_id)
	if _result_order.size() > RESULT_MEMORY:
		_results.erase(_result_order.pop_front())
