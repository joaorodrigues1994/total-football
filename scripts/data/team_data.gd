class_name TeamData
extends Resource
## Equipe e seu elenco (titulares e reservas, sem tamanho fixo). Não depende do lado A/B da partida.

@export var id := ""
@export var full_name := ""
@export var abbreviation := ""
@export var primary_color := Color.WHITE
@export var secondary_color := Color.WHITE
@export var entries: Array[RosterEntry] = []


func starter_for(slot: String) -> RosterEntry:
	for e in entries:
		if e.starter_slot == slot:
			return e
	return null


func reserves() -> Array[RosterEntry]:
	var list: Array[RosterEntry] = []
	for e in entries:
		if not e.is_starter():
			list.append(e)
	return list


func entry_of(player_id: String) -> RosterEntry:
	for e in entries:
		if e.player and e.player.id == player_id:
			return e
	return null


## Mensagens de erro do elenco (sem checar duplicidade entre times, que é do TeamRegistry); vazio = válido.
func validate() -> Array[String]:
	var errors: Array[String] = []
	var who := "time '%s'" % id
	if id.is_empty():
		errors.append("time sem id (%s)" % resource_path)
	if full_name.is_empty() or abbreviation.is_empty():
		errors.append("%s sem nome completo ou abreviação" % who)
	var players_seen := {}
	var numbers_seen := {}
	var slots_seen := {}
	for e in entries:
		if e == null or e.player == null:
			errors.append("%s com vínculo sem jogador" % who)
			continue
		var pid := e.player.id
		if players_seen.has(pid):
			errors.append("%s com jogador '%s' repetido" % [who, pid])
		players_seen[pid] = true
		if e.jersey_number < 0 or e.jersey_number > 99:
			errors.append("%s: número %d fora de 0..99 (%s)" % [who, e.jersey_number, pid])
		elif numbers_seen.has(e.jersey_number):
			errors.append("%s com número %d repetido" % [who, e.jersey_number])
		numbers_seen[e.jersey_number] = true
		if e.is_starter():
			if not Positions.SLOT_POSITIONS.has(e.starter_slot):
				errors.append("%s: vaga desconhecida '%s' (%s)" % [who, e.starter_slot, pid])
			elif not Positions.fits(e.player, e.starter_slot):
				errors.append("%s: %s (%s) não é compatível com a vaga %s" % [who, pid, e.player.position, e.starter_slot])
			if slots_seen.has(e.starter_slot):
				errors.append("%s com mais de um titular na vaga %s" % [who, e.starter_slot])
			slots_seen[e.starter_slot] = true
	for slot in Positions.required_slots():
		if not slots_seen.has(slot):
			errors.append("%s sem titular na vaga %s" % [who, slot])
	return errors
