extends SceneTree
## Testes da fundação de times e jogadores (Etapa 1). Uso: Godot --headless --path . -s tests/data_suite.gd

var _fails := 0
var _checks := 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("FALHA: ", what)


func _init() -> void:
	var reg := TeamRegistry.new()
	_check(reg.load_all(), "carrega e valida os dados: %s" % str(reg.errors))
	_check(reg.teams.size() == 2 and reg.teams.has("gen_a") and reg.teams.has("gen_b"), "dois times genéricos")
	_check(reg.players.size() == 94, "94 jogadores cadastrados (%d)" % reg.players.size())
	var team_a: TeamData = reg.teams["gen_a"]
	var team_b: TeamData = reg.teams["gen_b"]
	_check(team_a.entries.size() == 47 and team_b.entries.size() == 47, "47 vínculos por time")
	_check(team_a.reserves().size() == 2, "2 reservas")
	_check(team_a.primary_color != team_b.primary_color, "cores primárias distintas")
	_equivalence(team_a)
	_equivalence(team_b)
	_match_state(team_a)
	_invalid_cases(team_a, reg)
	print("RES data_suite: ", _checks, " verificações, ", _fails, " falhas")
	quit(1 if _fails > 0 else 0)


## Cada vaga de formação (e K/R) tem titular com os mesmos atributos de PlayerAttributes.for_role.
func _equivalence(team: TeamData) -> void:
	for slot in Positions.required_slots():
		var e := team.starter_for(slot)
		_check(e != null, "%s tem titular em %s" % [team.id, slot])
		if e == null:
			continue
		var expected := PlayerAttributes.for_role(slot)
		var same := true
		for attr in PlayerMatchState.ATTRIBUTES:
			if e.player.attributes.get(attr) != expected.get(attr):
				same = false
		_check(same, "%s/%s: atributos iguais a for_role" % [team.id, slot])
		_check(Positions.fits(e.player, slot), "%s/%s: posição compatível" % [team.id, slot])


func _match_state(team: TeamData) -> void:
	var data: PlayerData = team.starter_for("MLB").player
	var state := PlayerMatchState.new(data)
	var plain := state.effective_attributes()
	var same := true
	for attr in PlayerMatchState.ATTRIBUTES:
		if plain.get(attr) != data.attributes.get(attr):
			same = false
	_check(same, "sem modificadores o efetivo é igual ao base")
	state.modifiers["speed"] = -20
	state.modifiers["strength"] = 90
	_check(state.effective("speed") == 30, "modificador negativo")
	_check(state.effective("strength") == 100, "limite superior 100")
	state.modifiers["speed"] = -200
	_check(state.effective("speed") == 1, "limite inferior 1")
	_check(data.attributes.speed == 50 and data.attributes.strength == 50, "atributos-base intactos")
	_check(state.effective_attributes() != data.attributes, "efetivo é cópia, não o base")


func _invalid_cases(team: TeamData, reg: TeamRegistry) -> void:
	var p := _player("x1", "QB")
	_check(p.validate().is_empty(), "jogador válido de teste")
	p.id = ""
	_check(not p.validate().is_empty(), "rejeita jogador sem id")
	p = _player("x2", "ZZ")
	_check(not p.validate().is_empty(), "rejeita posição inválida")
	p = _player("x3", "QB")
	p.attributes.speed = 0
	_check(not p.validate().is_empty(), "rejeita atributo 0")
	p.attributes.speed = 101
	_check(not p.validate().is_empty(), "rejeita atributo 101")
	p = _player("x4", "QB")
	p.attributes = null
	_check(not p.validate().is_empty(), "rejeita jogador sem atributos")

	var t := _clone(team)
	_check(t.validate().is_empty(), "cópia do time é válida")
	t.entries[0].jersey_number = t.entries[1].jersey_number
	_check(not t.validate().is_empty(), "rejeita número repetido")
	t = _clone(team)
	t.entries.remove_at(0)
	_check(not t.validate().is_empty(), "rejeita vaga sem titular")
	t = _clone(team)
	t.entries[0].starter_slot = t.entries[1].starter_slot
	_check(not t.validate().is_empty(), "rejeita dois titulares na mesma vaga")
	t = _clone(team)
	t.entries[0].player.position = "K"
	_check(not t.validate().is_empty(), "rejeita titular incompatível com a vaga")
	t = _clone(team)
	t.id = ""
	_check(not t.validate().is_empty(), "rejeita time sem id")
	t = _clone(team)
	t.entries[0].player = null
	_check(not t.validate().is_empty(), "rejeita vínculo sem jogador")

	_check(team.validate().is_empty(), "time original intacto depois dos casos inválidos")

	# o mesmo jogador em dois elencos e jogador fora do cadastro
	var other := reg.teams["gen_b"] as TeamData
	var shared := team.duplicate(false) as TeamData
	shared.id = "gen_c"
	shared.entries = [team.entries[0]]
	_check(not TeamRegistry.check_cross([team, shared], reg.players).is_empty(), "rejeita jogador em dois elencos")
	_check(TeamRegistry.check_cross([team, other], reg.players).is_empty(), "times distintos não compartilham jogadores")
	_check(not TeamRegistry.check_cross([team], {}).is_empty(), "rejeita jogador não cadastrado")


func _player(id: String, position: String) -> PlayerData:
	var p := PlayerData.new()
	p.id = id
	p.display_name = "Teste"
	p.position = position
	p.attributes = PlayerAttributes.new()
	return p


## Cópia independente do time, dos vínculos e dos jogadores (duplicate(true) não copia os .tres externos).
func _clone(team: TeamData) -> TeamData:
	var t := TeamData.new()
	t.id = team.id
	t.full_name = team.full_name
	t.abbreviation = team.abbreviation
	for e in team.entries:
		var ne := RosterEntry.new()
		ne.jersey_number = e.jersey_number
		ne.starter_slot = e.starter_slot
		ne.player = PlayerData.new()
		ne.player.id = e.player.id
		ne.player.display_name = e.player.display_name
		ne.player.position = e.player.position
		ne.player.attributes = e.player.attributes.duplicate() as PlayerAttributes
		t.entries.append(ne)
	return t
