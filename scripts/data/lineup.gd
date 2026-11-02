class_name Lineup
extends RefCounted
## Escalação de um time numa partida: quem ocupa cada vaga. Começa como cópia dos titulares do TeamData e as
## substituições só mudam esta cópia (o TeamData é o dado permanente do time e não é alterado). Um jogador ocupa
## no máximo uma vaga; quem não ocupa nenhuma está no banco.

var team: TeamData
var log: Array[Dictionary] = []

var _slots := {}  # vaga -> PlayerData


func _init(team_data: TeamData) -> void:
	team = team_data
	for e in team.entries:
		if e.is_starter():
			_slots[e.starter_slot] = e.player


func occupant(slot: String) -> PlayerData:
	return _slots.get(slot)


## Vaga ocupada pelo jogador, ou "" se ele está no banco (ou não é do elenco).
func slot_of(player_id: String) -> String:
	for slot in _slots:
		if _slots[slot].id == player_id:
			return slot
	return ""


## Jogadores do elenco que não ocupam nenhuma vaga, na ordem do elenco.
func bench() -> Array[PlayerData]:
	var list: Array[PlayerData] = []
	for e in team.entries:
		if slot_of(e.player.id).is_empty():
			list.append(e.player)
	return list


## Jogadores do banco que podem ocupar a vaga.
func candidates_for(slot: String) -> Array[PlayerData]:
	var list: Array[PlayerData] = []
	for p in bench():
		if Positions.fits(p, slot):
			list.append(p)
	return list


func jersey_number(player_id: String) -> int:
	var entry := team.entry_of(player_id)
	return entry.jersey_number if entry else -1


## Motivo da recusa de pôr o jogador do banco na vaga; vazio = permitido.
func can_substitute(slot: String, player_id: String) -> String:
	if not _slots.has(slot):
		return "vaga desconhecida: %s" % slot
	var entry := team.entry_of(player_id)
	if entry == null:
		return "jogador %s não é do elenco" % player_id
	var current := slot_of(player_id)
	if current == slot:
		return "jogador %s já está na vaga %s" % [player_id, slot]
	if not current.is_empty():
		return "jogador %s já é titular na vaga %s" % [player_id, current]
	if not Positions.fits(entry.player, slot):
		return "%s (%s) não é compatível com a vaga %s" % [player_id, entry.player.position, slot]
	return ""


## O jogador do banco assume a vaga e o titular vai para o banco. Devolve false (sem alterar nada) se for inválido.
func substitute(slot: String, player_id: String) -> bool:
	if not can_substitute(slot, player_id).is_empty():
		return false
	var out: PlayerData = _slots[slot]
	_slots[slot] = team.entry_of(player_id).player
	log.append({"type": "substitute", "slot": slot, "out": out.id, "in": player_id})
	return true


## Motivo da recusa de trocar dois titulares entre si; vazio = permitido.
func can_swap(slot_a: String, slot_b: String) -> String:
	if slot_a == slot_b:
		return "as vagas são a mesma"
	if not _slots.has(slot_a) or not _slots.has(slot_b):
		return "vaga desconhecida"
	if not Positions.fits(_slots[slot_a], slot_b) or not Positions.fits(_slots[slot_b], slot_a):
		return "jogadores incompatíveis com a vaga do outro"
	return ""


func swap(slot_a: String, slot_b: String) -> bool:
	if not can_swap(slot_a, slot_b).is_empty():
		return false
	var a: PlayerData = _slots[slot_a]
	_slots[slot_a] = _slots[slot_b]
	_slots[slot_b] = a
	log.append({"type": "swap", "slot": slot_a, "other_slot": slot_b, "a": a.id, "b": _slots[slot_a].id})
	return true
