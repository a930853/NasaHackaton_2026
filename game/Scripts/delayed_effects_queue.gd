class_name DelayedEffectsQueue
extends RefCounted
## Cola de efectos diferidos: consecuencias que se aplican en un Sol futuro
## (cosechas listas, segunda salida al exterior, etc.).
## Cada entrada guarda un "outcome" con el mismo formato que una opción de evento
## ("effects", "add", "set"...), que GameState sabe aplicar.

var _entries: Array[Dictionary] = []


func enqueue(due_sol: int, outcome: Dictionary) -> void:
	_entries.append({"due_sol": due_sol, "outcome": outcome})


## Devuelve (y elimina) los outcomes que vencen en `sol` o antes.
func pop_due(sol: int) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	var remaining: Array[Dictionary] = []
	for entry in _entries:
		if int(entry["due_sol"]) <= sol:
			due.append(entry["outcome"])
		else:
			remaining.append(entry)
	_entries = remaining
	return due


func pending_count() -> int:
	return _entries.size()


func clear() -> void:
	_entries.clear()
