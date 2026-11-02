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


## Prepara cada tipo de jogada de chute (kickoff, punt, field goal, extra point).
func _kick_setup(m: Match, kind: String) -> void:
	m.rules.start_drive(0, 40.0)
	match kind:
		"kickoff":
			m.rules.start_kickoff(0)
			m._setup()
		"punt":
			m._setup(Match.PlayKind.PUNT)
		"field_goal":
			m._setup(Match.PlayKind.FIELD_GOAL)
		"extra_point":
			m.rules.next_play = GameRules.Next.EXTRA_POINT
			m._setup()


func _kicks(m: Match) -> void:
	for kind in ["kickoff", "punt", "field_goal", "extra_point"]:
		var first := {}
		for round in 2:
			_kick_setup(m, kind)
			_check(m.offense.size() == 11 and m.defense.size() == 11, "%s: 11 jogadores por lado" % kind)
			for p in m.offense + m.defense:
				var key := "%s/%d/%s" % [kind, p.team, p.role]
				_check(p.state != null, "%s tem estado" % key)
				if p.state == null:
					continue
				var team: TeamData = m.roster.teams[p.team]
				_check(p.player_id() == team.starter_for(p.role).player.id, "%s: id do titular da vaga" % key)
				var expected := PlayerAttributes.for_role(p.role)
				var same := true
				for attr in PlayerMatchState.ATTRIBUTES:
					if p.attributes.get(attr) != expected.get(attr):
						same = false
				_check(same, "%s: atributos iguais a for_role" % key)
				if first.has(key):
					_check(first[key] == p.state, "%s mantém o mesmo estado entre jogadas" % key)
				first[key] = p.state
	_kick_setup(m, "kickoff")
	_check(m._find(m.offense, "K").player_id() == "gen_a_k", "kickoff: chutador é o K do time A")
	_check(m._find(m.defense, "R").player_id() == "gen_b_r", "kickoff: retornador é o R do time B")
	_kick_setup(m, "field_goal")
	_check(m._find(m.offense, "C1").player_id() == "gen_a_c1", "field goal: holder é o C1 do time A")
	_check(m._find(m.defense, "B0").player_id() == "gen_b_b0", "field goal: B0 vem do elenco do time B")

	# times invertidos e vaga de special teams sem especialista
	var original := m.roster
	m.roster = MatchRoster.new(original.teams[1], original.teams[0])
	_kick_setup(m, "kickoff")
	_check(m._find(m.offense, "K").player_id() == "gen_b_k", "kickoff com times invertidos")
	var partial := TeamData.new()
	partial.id = "parcial"
	for e in original.teams[0].entries:
		if e.starter_slot != "C5":
			partial.entries.append(e)
	m.roster = MatchRoster.new(partial, original.teams[1])
	_kick_setup(m, "punt")
	var c5 := m._find(m.offense, "C5")
	_check(c5.state == null and c5.attributes.hitting_power == PlayerAttributes.for_role("C5").hitting_power, "C5 sem especialista usa for_role")
	m.roster = original
