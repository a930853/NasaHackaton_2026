class_name OptionInfo
extends RefCounted
## Textos de una opción que se enseñan a los jugadores (en el móvil o en el simulador).
## Está separado de la UI para que la pantalla de depuración y el futuro mando
## usen exactamente las mismas palabras.

const STAT_LABELS: Dictionary = {
	"health": "Health", "oxygen": "Oxygen", "energy": "Energy", "integrity": "Base strength",
}


## Lo que cuesta la opción: ahora, más tarde y cada mañana. (La probabilidad de éxito no se enseña.)
static func costs_text(option: Dictionary) -> String:
	var now_costs: Array[String] = _cost_parts(option.get("effects", {}))
	var text: String = "Costs: " + (", ".join(PackedStringArray(now_costs)) if not now_costs.is_empty() else "nothing")

	for delayed in option.get("delayed", []):
		var later: Array[String] = _cost_parts(delayed.get("effects", {}))
		if not later.is_empty():
			var after: int = int(delayed.get("after_sols", 1))
			text += "  +  Later: %s (in %d Sol%s)" % [", ".join(PackedStringArray(later)), after, "" if after == 1 else "s"]
		if int(delayed.get("away_all", 0)) > 0:
			var after_all: int = int(delayed.get("after_sols", 1))
			text += "  +  In %d Sol%s the whole crew is busy for %d Sol%s" % [
				after_all, "" if after_all == 1 else "s", int(delayed["away_all"]), "" if int(delayed["away_all"]) == 1 else "s"]

	var condition: Dictionary = option.get("start_condition", {})
	if condition.has("sequence"):
		var steps: Array[String] = []
		for step in condition["sequence"]:
			steps.append(", ".join(PackedStringArray(_cost_parts(step))))
		if not steps.is_empty():
			text += "  +  Each morning: " + "  then  ".join(PackedStringArray(steps))
	elif condition.has("daily"):
		var daily: Array[String] = _cost_parts(condition["daily"])
		if not daily.is_empty():
			text += "  +  Each morning for %d Sols: %s" % [int(condition.get("sols", 1)), ", ".join(PackedStringArray(daily))]

	var away: int = int(option.get("away_sols", 0))
	if away > 0:
		var role: Variant = option.get("role")
		var who: String = "The whole crew" if role == null else "The %s" % GameState.ROLE_NAMES[str(role)]
		text += "  +  %s is busy for %d Sol%s" % [who, away, "" if away == 1 else "s"]
	return text


## Solo los efectos negativos (lo que se gasta), en el orden fijo de las barras.
static func _cost_parts(effects: Dictionary) -> Array[String]:
	var parts: Array[String] = []
	for stat in GameState.STAT_NAMES:
		var amount: int = int(effects.get(stat, 0))
		if amount < 0:
			parts.append("%s %d" % [STAT_LABELS[stat], amount])
	return parts
