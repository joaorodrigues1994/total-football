extends SceneTree
## Testes da Etapa 2: identidade e estado de partida ligados ao spawn dos jogadores de scrimmage.
## Uso: Godot --headless --path . -s tests/identity_suite.gd

var _fails := 0
var _checks := 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("FALHA: ", what)


func _init() -> void:
	var s = load("res://scenes/main.tscn").instantiate()
	root.add_child(s)
	var m: Match = s.get_node("Match")
	await physics_frame
	_check(m.roster != null, "roster carregado pela partida")
	_identity_and_equivalence(m)
	_modifiers(m)
	_swapped_teams(m)
	_fallback(m)
	_kicks(m)
	print("RES identity_suite: ", _checks, " verificações, ", _fails, " falhas")
	quit(1 if _fails > 0 else 0)


func _fresh_play(m: Match, possession: int) -> void:
	m.rules.start_drive(possession, 40.0)
	m._setup()


## Vaga -> id do jogador de cada lado, na jogada atual.
func _ids(m: Match) -> Dictionary:
	var ids := {}
	for p in m.offense + m.defense:
		ids["%d/%s" % [p.team, p.role]] = p.player_id()
	return ids


func _identity_and_equivalence(m: Match) -> void:
	var first := {}
	var states := {}
	for round in 6:
		_fresh_play(m, round % 2)
		var ids := _ids(m)
		for p in m.offense + m.defense:
			var key := "%d/%s" % [p.team, p.role]
			_check(p.state != null, "%s tem estado" % key)
			if p.state == null:
				continue
			var team: TeamData = m.roster.teams[p.team]
			_check(p.player_id() == team.starter_for(p.role).player.id, "%s: id do titular do time do lado" % key)
			if first.has(key):
				_check(ids[key] == first[key], "%s mantém o id entre jogadas" % key)
				_check(states[key] == p.state, "%s mantém o mesmo PlayerMatchState" % key)
			else:
				first[key] = ids[key]
				states[key] = p.state
			var expected := PlayerAttributes.for_role(p.role)
			var same := true
			for attr in PlayerMatchState.ATTRIBUTES:
				if p.attributes.get(attr) != expected.get(attr):
					same = false
			_check(same, "%s: atributos iguais a for_role" % key)
			_check(p.attributes != p.state.data.attributes, "%s: atributos do jogador são cópia, não o base" % key)
	_check(first.size() == 44, "44 vagas distintas vistas nos dois lados (%d)" % first.size())


func _modifiers(m: Match) -> void:
	_fresh_play(m, 0)
	var rb := m._find(m.offense, "RB")
	var id := rb.player_id()
	_check(rb.attributes.speed == 50, "RB começa com velocidade 50")
	m.roster.state_of(id).modifiers["speed"] = -10
	_fresh_play(m, 0)
	rb = m._find(m.offense, "RB")
	_check(rb.attributes.speed == 40, "modificador aparece no jogador em campo")
	_check(rb.state.data.attributes.speed == 50, "atributo-base do PlayerData intacto")
	m.roster.state_of(id).modifiers.clear()
	_fresh_play(m, 0)
	_check(m._find(m.offense, "RB").attributes.speed == 50, "sem modificador volta ao base")


func _swapped_teams(m: Match) -> void:
	var a := m.roster.teams[0]
	var b := m.roster.teams[1]
	var original := m.roster
	m.roster = MatchRoster.new(b, a)
	_fresh_play(m, 0)
	_check(m._find(m.offense, "QB").player_id() == "gen_b_qb", "lado A com o time gen_b: ataque do lado A usa jogadores de gen_b")
	_check(m._find(m.defense, "MLB").player_id() == "gen_a_mlb", "defesa do lado B usa jogadores de gen_a")
	_check(m._find(m.offense, "QB").team == Player.Team.A, "o lado lógico continua A")
	m.roster = original


func _fallback(m: Match) -> void:
	var original := m.roster
	var partial := TeamData.new()
	partial.id = "parcial"
	for e in original.teams[1].entries:
		if e.starter_slot != "MLB":
			partial.entries.append(e)
	m.roster = MatchRoster.new(original.teams[0], partial)
	_fresh_play(m, 0)  # a defesa é o lado B
	var mlb := m._find(m.defense, "MLB")
	_check(mlb.state == null and mlb.player_id() == "", "vaga sem titular fica sem estado")
	_check(mlb.attributes.hitting_power == PlayerAttributes.for_role("MLB").hitting_power, "vaga sem titular usa for_role")
	_check(m._find(m.defense, "LDE").state != null, "demais vagas continuam vindo do elenco")
	m.roster = original


## Chutes e retornos seguem por papel até a etapa 3.
func _kicks(m: Match) -> void:
	m.rules.start_kickoff(0)
	m._setup()
	for p in m.offense + m.defense:
		_check(p.state == null, "kickoff: %s sem estado (fallback por papel)" % p.role)
		break
	m.rules.start_drive(0, 40.0)
	m._setup(Match.PlayKind.PUNT)
	for p in m.offense + m.defense:
		_check(p.state == null, "punt: %s sem estado (fallback por papel)" % p.role)
		break
