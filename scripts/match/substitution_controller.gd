class_name SubstitutionController
extends RefCounted
## Lógica do painel de substituição do humano (sem desenho): escolhe uma vaga da escalação e um reserva
## compatível do banco. Só oferece trocas válidas; quem confirma e valida de fato é o Lineup.
## Ações: "up", "down", "left", "right", "confirm", "cancel".

signal substituted

var is_open := false

var _lineup: Lineup
var _slots: Array[String] = []
var _column := 0  # 0 = lista de vagas, 1 = lista de reservas
var _slot_index := 0
var _bench_index := 0
var _message := ""


func open(lineup: Lineup, slots: Array[String]) -> void:
	_lineup = lineup
	_slots = slots
	_column = 0
	_slot_index = 0
	_bench_index = 0
	_message = ""
	is_open = true


func close() -> void:
	is_open = false


func selected_slot() -> String:
	return _slots[_slot_index]


func candidates() -> Array[PlayerData]:
	return _lineup.candidates_for(selected_slot())


func press(action: String) -> void:
	if not is_open:
		return
	if _column == 0:
		match action:
			"up":
				_slot_index = posmod(_slot_index - 1, _slots.size())
				_message = ""
			"down":
				_slot_index = posmod(_slot_index + 1, _slots.size())
				_message = ""
			"right", "confirm":
				if candidates().is_empty():
					_message = "NO BENCH PLAYER FOR THIS SLOT"
				else:
					_column = 1
					_bench_index = 0
					_message = ""
			"cancel":
				close()
	else:
		var options := candidates()
		match action:
			"up":
				_bench_index = posmod(_bench_index - 1, options.size())
			"down":
				_bench_index = posmod(_bench_index + 1, options.size())
			"left", "cancel":
				_column = 0
			"confirm":
				var incoming: PlayerData = options[_bench_index]
				if _lineup.substitute(selected_slot(), incoming.id):
					_message = "IN: #%d %s" % [_lineup.jersey_number(incoming.id), incoming.display_name]
					_column = 0
					substituted.emit()
				else:
					_message = "INVALID SUBSTITUTION"


## Dados para o painel desenhar.
func info() -> Dictionary:
	var rows: Array[Dictionary] = []
	for slot in _slots:
		var p := _lineup.occupant(slot)
		rows.append({"slot": slot, "text": "%s  #%d %s (%s)" % [slot, _lineup.jersey_number(p.id), p.display_name, p.position]})
	var bench: Array[String] = []
	for p in candidates():
		bench.append("#%d %s (%s)" % [_lineup.jersey_number(p.id), p.display_name, p.position])
	return {
		"visible": is_open, "rows": rows, "bench": bench, "column": _column,
		"slot_index": _slot_index, "bench_index": _bench_index, "message": _message,
	}
