extends SceneTree
## Testes da Etapa 5: escalação por partida (Lineup), substituições e painel do humano.
## Uso: Godot --headless --path . -s tests/substitution_suite.gd

var _fails := 0
var _checks := 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("FALHA: ", what)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _init() -> void:
	var s = load("res://scenes/main.tscn").instantiate()
	root.add_child(s)
	var m: Match = s.get_node("Match")
	await physics_frame
	_lineup(m.roster.teams[0])
	_roster(m)
	await _panel(m)
	await _full_play(m)
	print("RES substitution_suite: ", _checks, " verificações, ", _fails, " falhas")
	quit(1 if _fails > 0 else 0)


func _lineup(team: TeamData) -> void:
	var l := Lineup.new(team)
	_check(l.occupant("QB").id == "gen_a_qb", "titular inicial do QB")
	_check(l.bench().size() == 2, "banco com os 2 reservas")
	_check(l.candidates_for("QB").size() == 1 and l.candidates_for("QB")[0].id == "gen_a_res_qb", "só o reserva QB é candidato ao QB")
	_check(l.candidates_for("WR2").size() == 1 and l.candidates_for("WR2")[0].id == "gen_a_res_wr", "reserva WR candidato a WR2")
	_check(l.candidates_for("LDE").is_empty(), "ninguém no banco para LDE")
	_check(l.jersey_number("gen_a_qb") == team.entry_of("gen_a_qb").jersey_number, "número da camisa vem do vínculo")

	# recusas
	_check(not l.can_substitute("QB", "gen_a_res_wr").is_empty(), "recusa reserva incompatível (WR no QB)")
	_check(not l.can_substitute("QB", "gen_a_lt").is_empty(), "recusa quem já é titular em outra vaga")
	_check(not l.can_substitute("QB", "gen_a_qb").is_empty(), "recusa jogador na própria vaga")
	_check(not l.can_substitute("QB", "gen_b_res_qb").is_empty(), "recusa jogador de outro time")
	_check(not l.can_substitute("XX", "gen_a_res_qb").is_empty(), "recusa vaga desconhecida")
	_check(not l.substitute("QB", "gen_a_res_wr") and l.occupant("QB").id == "gen_a_qb", "substituição inválida não altera nada")
	_check(l.log.is_empty(), "nenhuma troca registrada nos casos inválidos")

	# substituição e volta
	_check(l.substitute("QB", "gen_a_res_qb"), "reserva QB entra")
	_check(l.occupant("QB").id == "gen_a_res_qb", "reserva ocupa a vaga")
	_check(l.slot_of("gen_a_qb") == "" and l.bench().any(func(p): return p.id == "gen_a_qb"), "titular anterior vai para o banco")
	_check(l.slot_of("gen_a_res_qb") == "QB", "slot_of do reserva")
	_check(l.log.size() == 1 and l.log[0]["out"] == "gen_a_qb" and l.log[0]["in"] == "gen_a_res_qb", "troca registrada")
	_check(team.starter_for("QB").player.id == "gen_a_qb", "TeamData intacto")
	_check(l.substitute("QB", "gen_a_qb"), "titular original volta")

	# troca entre titulares
	_check(l.swap("WR1", "WR2"), "troca WR1 e WR2")
	_check(l.occupant("WR1").id == "gen_a_wr2" and l.occupant("WR2").id == "gen_a_wr1", "ocupantes trocados")
	_check(not l.can_swap("QB", "WR1").is_empty(), "recusa troca entre posições incompatíveis")
	_check(not l.can_swap("WR1", "WR1").is_empty(), "recusa troca da vaga consigo mesma")
	_check(not l.swap("QB", "WR1"), "troca inválida não altera nada")
	_check(team.starter_for("WR1").player.id == "gen_a_wr1", "TeamData intacto após troca")
	# cada jogador numa vaga só
	var seen := {}
	for slot in Positions.required_slots():
		var id := l.occupant(slot).id
		_check(not seen.has(id), "jogador %s em uma única vaga" % id)
		seen[id] = true


func _roster(m: Match) -> void:
	var r := MatchRoster.new(m.roster.teams[0], m.roster.teams[1])
	var before := r.state_for(0, "QB")
	_check(before.data.id == "gen_a_qb", "estado inicial do QB")
	r.lineups[0].substitute("QB", "gen_a_res_qb")
	var after := r.state_for(0, "QB")
	_check(after.data.id == "gen_a_res_qb", "state_for devolve o reserva depois da troca")
	_check(r.state_for(0, "QB") == after, "estado do reserva é reaproveitado")
	_check(r.state_of("gen_a_qb") == before, "estado do titular anterior preservado")
	_check(r.state_for(1, "QB").data.id == "gen_b_qb", "o outro time não é afetado")


## Painel pelo teclado, no menu de jogadas, com o humano no ataque.
func await_menu(m: Match, possession: int) -> void:
	m.roster = MatchRoster.new(m.roster.teams[0], m.roster.teams[1])
	m.rules.start_drive(possession, 40.0)
	m._setup()
	await _frames(3)


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(2)


func _panel(m: Match) -> void:
	await await_menu(m, 0)
	_check(m.state == Match.State.PLAY_SELECTION, "menu de jogadas aberto")
	var qb: Player = m._find(m.offense, "QB")
	_check(qb.player_id() == "gen_a_qb", "começa com o titular")
	var clock_before := m._play_clock.time
	await _tap("btn_sub")
	_check(m._sub.is_open, "tecla U abre o painel")
	var clock_open := m._play_clock.time
	await _frames(40)
	_check(is_equal_approx(m._play_clock.time, clock_open), "play clock parado com o painel aberto")
	_check(clock_open <= clock_before, "play clock não andou para trás")

	# vagas do ataque: QB é a 7ª (índice 6)
	for i in 6:
		await _tap("ui_down")
	_check(m._sub.selected_slot() == "QB", "cursor na vaga QB")
	await _tap("btn_a")  # entra na lista de reservas
	await _tap("btn_a")  # confirma
	_check(m._find(m.offense, "QB").player_id() == "gen_a_res_qb", "reserva QB em campo já nesta formação")
	_check(m._find(m.offense, "QB").attributes.hitting_power == PlayerAttributes.for_role("QB").hitting_power, "atributos do reserva (QB)")
	_check(m._off_choice.is_empty(), "nenhuma jogada foi escolhida pelo painel")
	await _tap("btn_s")  # fecha
	_check(not m._sub.is_open, "S fecha o painel")
	_check(m._off_choice.is_empty(), "fechar o painel não escolhe jogada")
	await _frames(30)
	_check(m._play_clock.time < clock_open, "play clock volta a andar")

	# vale para as próximas jogadas
	m.rules.start_drive(0, 40.0)
	m._setup()
	await _frames(3)
	_check(m._find(m.offense, "QB").player_id() == "gen_a_res_qb", "substituição vale para a jogada seguinte")

	# vaga sem reserva compatível
	await _tap("btn_sub")
	await _tap("btn_a")  # vaga LT
	_check(m._sub._column == 0, "sem reserva para LT o painel não entra na lista de reservas")
	_check(m._sub.info()["message"] != "", "mensagem de vaga sem reserva")
	await _tap("btn_sub")
	_check(not m._sub.is_open, "U fecha o painel")

	# defesa humana: painel lista as vagas da defesa
	await await_menu(m, 1)
	await _tap("btn_sub")
	_check(m._sub.is_open and m._sub.info()["rows"].size() == 11 and m._sub.info()["rows"][0]["slot"] == "LDE", "defesa: 11 vagas da defesa")
	await _tap("btn_s")

	# só abre no menu de jogadas
	m.rules.start_drive(0, 40.0)
	m._setup()
	await _frames(3)
	Input.action_press("btn_a")
	await _frames(3)
	Input.action_release("btn_a")
	m._off_choice = Playbook.offense_play("up", false)
	await _tap("btn_sub")
	_check(not m._sub.is_open, "não abre depois que a jogada foi escolhida")


## Uma jogada de passe completa com o QB reserva em campo, sem erros.
func _full_play(m: Match) -> void:
	await await_menu(m, 0)
	m.roster.lineups[0].substitute("QB", "gen_a_res_qb")
	m.rules.start_drive(0, 40.0)
	m._setup()
	await _frames(3)
	Engine.time_scale = 8.0
	Input.action_press("ui_up")
	Input.action_press("btn_s")
	await _frames(4)
	Input.action_release("ui_up")
	Input.action_release("btn_s")
	var t := 0.0
	var cool := 0.0
	while m.state != Match.State.DEAD and t < 60.0:
		await physics_frame
		var dt := root.get_physics_process_delta_time()
		t += dt
		cool -= dt
		if cool <= 0.0 and m.state == Match.State.PRE_SNAP:
			cool = 1.0
			Input.action_press("btn_a")
			await _frames(3)
			Input.action_release("btn_a")
	Engine.time_scale = 1.0
	_check(m.state == Match.State.DEAD, "jogada com o QB reserva chega ao fim (%s)" % m.play_result)
	_check(m._qb.player_id() == "gen_a_res_qb", "o QB da jogada era o reserva")
