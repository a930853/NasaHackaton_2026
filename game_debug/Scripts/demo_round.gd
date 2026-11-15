class_name DemoRound
extends RefCounted
## Una ronda de votación de prueba: todos los jugadores eligen una opción.
##
## Aquí está la parte que valida cada `choose` tal y como pide el contrato
## (docs/es/godot/red.md, "Validar un choose"). No sabe nada de la red: recibe
## datos y devuelve un veredicto. Así se puede leer y probar por separado.

var event_id := ""                 ## Id de ESTA aparición ("demo#1", "demo#2"…).
var options: Array = []            ## [{ "id": "red", "label": "Rojo" }, …]
var eligible: Array[String] = []   ## playerIds que pueden votar en esta ronda.
var decisions := {}                ## playerId -> optionId (elecciones aceptadas).
var closed := true

var _count := 0
## actionId -> veredicto. Se guarda de TODAS las rondas para reconocer reenvíos
## que llegan cuando la ronda ya se cerró.
var _verdicts := {}


## Abre una ronda nueva y devuelve su eventId.
func open(player_ids: Array[String], round_options: Array) -> String:
	_count += 1
	event_id = "demo#%d" % _count
	options = round_options
	eligible = player_ids
	decisions = {}
	closed = false
	return event_id


func close() -> void:
	closed = true


func everyone_decided() -> bool:
	return eligible.all(func(pid: String) -> bool: return decisions.has(pid))


func option_label(option_id: String) -> String:
	for option in options:
		if option["id"] == option_id:
			return option["label"]
	return option_id


## Decide si se acepta una elección.
## Devuelve { accepted: bool, reason: String, duplicate: bool }.
func judge(player_id: String, action_id: String, chosen_event_id: String, option_id: String) -> Dictionary:
	# 1. Duplicado (mismo actionId): la misma respuesta que la primera vez,
	#    sin volver a aplicar nada.
	if _verdicts.has(action_id):
		var previous: Dictionary = _verdicts[action_id].duplicate()
		previous["duplicate"] = true
		return previous

	var reason := ""
	if closed or chosen_event_id != event_id:
		reason = "event_closed"        # 2. Ronda antigua o ya cerrada.
	elif player_id not in eligible:
		reason = "not_eligible"        # 3. Este jugador no vota aquí.
	elif not options.any(func(o: Dictionary) -> bool: return o["id"] == option_id):
		reason = "invalid_option"      # 4. La opción no existe.
	elif decisions.has(player_id):
		reason = "already_decided"     # 5. Ya votó (con otro actionId).

	if reason == "":
		decisions[player_id] = option_id   # 6. Aceptada: queda bloqueada.

	# Los rechazos también se memorizan.
	var verdict := {"accepted": reason == "", "reason": reason, "duplicate": false}
	_verdicts[action_id] = verdict
	return verdict
