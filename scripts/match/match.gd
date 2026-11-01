class_name Match
extends Node2D
## Monta a partida e conduz a jogada: formação, snap, corrida, passe, tackles, chutes e regras.

enum State { PRE_SNAP, SNAP, HANDOFF, DROPBACK, PASSING, FLIGHT, KICK_FLIGHT, RUNNING, DEAD }
enum PlayType { RUN, PASS }
enum PlayKind { SCRIMMAGE, PUNT, FIELD_GOAL, KICKOFF, EXTRA_POINT }
enum Side { OFFENSE, DEFENSE }

## O humano controla o Time A.
const HUMAN_TEAM := 0
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const STANCE_ROLES := ["LT", "LG", "C", "RG", "RT", "TE", "LDE", "LDT", "RDT", "RDE"]
const START_ROLES := ["WR1", "WR2", "WR3"]
const READY_ROLES := ["RB"]
const RUSH_ROLES := ["LDE", "LDT", "RDT", "RDE"]
## Retornador: não bloqueia, só recebe a bola nos chutes.
const RECEIVER_ROLES := ["R"]
const SNAP_TIME := 0.3
const HANDOFF_DISTANCE := 18.0
## Depois da entrega o QB sai lateralmente da frente do RB por este tempo.
const CLEAR_TIME := 0.7
const DROPBACK_YARDS := 5.0
const BALL_SPEED := 360.0
const KICK_SPEED := 300.0
const CATCH_RADIUS := 20.0
const KICK_CATCH_RADIUS := 30.0
## Contato (corpos se tocam a 14 px) que derruba o portador.
const TACKLE_RADIUS := 16.0
## Depois de errar o tackle (portador em juke) o defensor não tenta de novo por este tempo.
const MISS_COOLDOWN := 0.6
const GET_UP_TIME := 0.8
## Na defesa a CPU dá o snap/chute depois deste tempo (janela para trocar de jogador com A).
const DEFENSE_SNAP_DELAY := 5.0
## Tempo com a formação de chute em campo antes do chute escolhido (punt/field goal).
const KICK_FORMATION_TIME := 0.7
## Pausa entre o fim da jogada e a formação seguinte.
const NEXT_PLAY_DELAY := 1.5
const MESSAGE_TIME := 2.5
## O ataque fica deslocado para o seu lado da tela, mostrando mais campo à frente.
const CAMERA_LOOK_AHEAD := 170.0
## Margem mínima (px) entre o QB e a borda da tela durante o passe.
const CAMERA_QB_MARGIN := 50.0

@export var camera: MatchCamera

var rules := GameRules.new()
var state := State.PRE_SNAP
var play_type := PlayType.RUN
var play_kind := PlayKind.SCRIMMAGE
## Lado controlado pelo humano, definido pela posse de bola.
var human_side := Side.OFFENSE
## Direção de ataque do time com a bola: +1 = para a direita, -1 = para a esquerda.
var attack_dir := 1.0
var play_result := ""
## Time com a bola (ou que chuta) e time que defende (ou recebe o chute).
## Esquemas de bloqueio das jogadas de ataque (trocados pelo menu de jogadas na etapa 11).
var run_scheme := "run_middle"
var pass_scheme := "pass_short"
var offense: Array[Player] = []
var defense: Array[Player] = []
var scrimmage_spot := Vector2.ZERO

var _controller: HumanController
var _hud := DebugHud.new()
var _ball: Ball
var _anchor: Node2D
var _qb: Player
var _rb: Player
var _kicker: Player
var _carrier: Player
var _receivers: Array[Player] = []
var _block_system: BlockSystem
var _runners: Array[RouteRunner] = []
var _target_index := 0
var _defense_index := 0
var _presnap_time := 0.0
var _kick_countdown := 0.0
var _dead_time := 0.0
var _message := ""
var _message_time := 0.0
var _prompt := ""
var _flight: PassFlight
var _kick_landing := Vector2.ZERO
var _kick_landing_spot := 0.0
var _kick_good := false
var _in_return := false
var _snap_progress := 0.0
var _snap_from := Vector2.ZERO
var _clear_time := 0.0
var _clear_side := -1.0
var _dropback_x := 0.0


func _ready() -> void:
	InputSetup.ensure()
	add_child(_hud)
	_block_system = BlockSystem.new()
	_block_system.protect_fn = _block_protect_point
	add_child(_block_system)  # antes dos jogadores: atualiza o empurrão antes de eles se moverem
	_setup()


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("debug_reset"):  # TEMPORÁRIO
		_setup()
		return
	if Input.is_action_just_pressed("debug_swap_side") and state == State.PRE_SNAP:  # TEMPORÁRIO
		rules.flip_possession_same_spot()
		_setup()
		return
	if rules.tick(delta):  # quarto acabou entre jogadas
		_show_message("END OF QUARTER")
		_setup()
		return
	match state:
		State.PRE_SNAP:
			if _update_pre_snap(delta):
				return
		State.SNAP:
			_snap_progress = minf(_snap_progress + delta / SNAP_TIME, 1.0)
			_ball.world_pos = _snap_from.lerp(_hands(_snap_target()), _snap_progress)
			if _snap_progress >= 1.0:
				if play_kind == PlayKind.SCRIMMAGE:
					_carrier = _qb
					state = State.HANDOFF if play_type == PlayType.RUN else State.DROPBACK
					_dropback_x = _qb.global_position.x - attack_dir * FieldConstants.yards_to_px(DROPBACK_YARDS)
				else:
					_launch_kick()
		State.HANDOFF:
			_update_handoff()
		State.DROPBACK:
			_ball.world_pos = _hands(_qb)
			_frame_pass()
			_pass_inputs()
			if state == State.DROPBACK:
				_qb.input_dir = Vector2(-attack_dir, 0.0)
				if (_qb.global_position.x - _dropback_x) * attack_dir <= 0.0:
					_qb.input_dir = Vector2.ZERO
					_qb.facing = Vector2(attack_dir, 0.0)
					_controller.controlled = _qb
					_controller.enabled = true
					state = State.PASSING
		State.PASSING:
			_ball.world_pos = _hands(_qb)
			_frame_pass()
			_pass_inputs()
		State.FLIGHT:
			_update_flight(delta)
		State.KICK_FLIGHT:
			_update_kick_flight(delta)
		State.RUNNING:
			_ball.world_pos = _hands(_carrier)
			_clear_qb(delta)
			if human_side == Side.OFFENSE:
				if Input.is_action_just_pressed("btn_s"):
					_carrier.try_juke()
				if Input.is_action_just_pressed("btn_d"):
					_carrier.try_dive()
			elif _carrier.action != Player.Action.DOWN:
				_carrier.input_dir = Vector2(attack_dir, 0.0)  # CPU: corre reto para a frente
		State.DEAD:
			if _carrier:
				_ball.world_pos = _hands(_carrier)
			_clear_qb(delta)
			_dead_time += delta
			if _dead_time >= NEXT_PLAY_DELAY and not rules.game_over:
				_setup()
				return
	if state in [State.HANDOFF, State.DROPBACK, State.PASSING, State.RUNNING]:
		_check_touchdown()
	if state in [State.HANDOFF, State.DROPBACK, State.PASSING, State.RUNNING]:
		_check_tackles()
	_update_camera_focus()
	_message_time = maxf(_message_time - delta, 0.0)
	var banner := _message if _message_time > 0.0 else (_prompt if state == State.PRE_SNAP else "")
	_hud.show_rules(rules, banner)


## O retornador do humano corre sozinho até o ponto de queda enquanto a bola está no ar.
func is_auto_moving(player: Player) -> bool:
	return state == State.KICK_FLIGHT and human_side == Side.DEFENSE and player.role == "R" 			and play_kind in [PlayKind.KICKOFF, PlayKind.PUNT]


## Na defesa o humano segue a bola (inclusive o chute no ar); antes do chute, o retornador selecionado.
func _update_camera_focus() -> void:
	if human_side != Side.DEFENSE:
		return
	if play_kind == PlayKind.SCRIMMAGE or _in_return or state == State.KICK_FLIGHT:
		_anchor.global_position = _ball.world_pos
		camera.target = _anchor
	elif _controller.controlled:
		camera.target = _controller.controlled


## Retorna true se a formação foi refeita (a jogada deste frame não deve continuar).
func _update_pre_snap(delta: float) -> bool:
	if rules.game_over:
		return false
	if _kick_countdown > 0.0:  # formação de punt/field goal já escolhida
		_kick_countdown -= delta
		if _kick_countdown <= 0.0:
			_start_play()
		return false
	if human_side == Side.OFFENSE:
		if Input.is_action_just_pressed("btn_a"):
			return _offense_chooses()
		return false
	if Input.is_action_just_pressed("btn_a"):
		_defense_index = (_defense_index + 1) % defense.size()
		_controller.controlled = defense[_defense_index]
	_presnap_time -= delta
	if _presnap_time <= 0.0:
		return _cpu_offense_chooses()
	return false


## Humano no ataque apertou A: direção escolhe a jogada (Esquerda = passe).
func _offense_chooses() -> bool:
	var down_held := Input.is_action_pressed("ui_down")
	if play_kind == PlayKind.EXTRA_POINT and rules.conversion_open and down_held:
		rules.choose_conversion(true)  # Baixo + A: conversão de 2 pontos
		_setup()
		return true
	if play_kind == PlayKind.SCRIMMAGE and rules.next_play == GameRules.Next.SCRIMMAGE and rules.down == 4:
		if down_held:
			_begin_kick(PlayKind.PUNT)
			return true
		if Input.is_action_pressed("ui_right"):
			_begin_kick(PlayKind.FIELD_GOAL)
			return true
	_start_play()
	return false


## CPU no ataque: no 4º down chuta field goal ou punt; senão corre.
func _cpu_offense_chooses() -> bool:
	if play_kind == PlayKind.SCRIMMAGE and rules.next_play == GameRules.Next.SCRIMMAGE and rules.down == 4:
		if rules.kick_distance() <= 47.0:
			_begin_kick(PlayKind.FIELD_GOAL)
			return true
		if rules.ball_on < 55.0:
			_begin_kick(PlayKind.PUNT)
			return true
	_start_play()
	return false


func _begin_kick(kind: PlayKind) -> void:
	_setup(kind)
	_kick_countdown = KICK_FORMATION_TIME


func _start_play() -> void:
	var is_pass := human_side == Side.OFFENSE and Input.is_action_pressed("ui_left") \
			and play_kind == PlayKind.SCRIMMAGE
	play_type = PlayType.PASS if is_pass else PlayType.RUN
	_snap_progress = 0.0
	_snap_from = _ball.world_pos
	if human_side == Side.DEFENSE:
		_controller.enabled = true  # a troca de jogador fica travada a partir do snap
	match play_kind:
		PlayKind.SCRIMMAGE:
			if rules.next_play == GameRules.Next.TWO_POINT:
				rules.begin_untimed_play()
			else:
				rules.snap()
			_rb.pose = ""
			_block_system.begin(pass_scheme if is_pass else run_scheme, offense, defense, attack_dir)
			state = State.SNAP
			if is_pass:
				for i in _receivers.size():
					var p := _receivers[i]
					p.pose = ""
					_runners[i].start(Routes.PASS_TEST[p.role], p.global_position, attack_dir)
				_set_target(0)
		PlayKind.PUNT, PlayKind.FIELD_GOAL:
			rules.snap()
			state = State.SNAP
		PlayKind.KICKOFF, PlayKind.EXTRA_POINT:
			rules.begin_untimed_play()
			if play_kind == PlayKind.EXTRA_POINT:
				state = State.SNAP
			else:
				_launch_kick()


func _snap_target() -> Player:
	return _qb if play_kind == PlayKind.SCRIMMAGE else _kicker


## Para onde cada jogador com IA vai. null = fica parado.
func defender_target(player: Player) -> Variant:
	var role := player.role
	if play_kind != PlayKind.SCRIMMAGE and not _in_return:
		if state == State.KICK_FLIGHT and play_kind in [PlayKind.KICKOFF, PlayKind.PUNT]:
			if role == "R" or (player in offense and role != "K"):
				return _kick_landing  # retornador vai ao ponto de queda; cobertura corre atrás da bola
		return null
	match state:
		State.SNAP, State.HANDOFF, State.DROPBACK, State.PASSING:
			if player in defense and (play_type == PlayType.RUN or role in RUSH_ROLES):
				return (_carrier if _carrier else _qb).global_position
		State.RUNNING:
			if player in defense:
				return _carrier.global_position
	return null


## Ponto que o bloqueio protege: portador, ponto de queda do chute ou o QB.
func _block_protect_point() -> Vector2:
	if _carrier:
		return _carrier.global_position
	if state == State.KICK_FLIGHT:
		return _kick_landing
	return _qb.global_position


## Retorno de kickoff/punt: o time que recebe (menos o retornador) bloqueia a cobertura.
func _begin_return_blocks() -> void:
	var blockers: Array[Player] = []
	var cover: Array[Player] = []
	for p in defense:
		if p.role not in RECEIVER_ROLES:
			blockers.append(p)
	for p in offense:
		if p.role != "K":
			cover.append(p)
	_block_system.begin("kick_return" if play_kind == PlayKind.KICKOFF else "punt_return",
			blockers, cover, -attack_dir)


func _check_touchdown() -> void:
	if _carrier == null or _carrier.action == Player.Action.DOWN:
		return
	if _spot_from_x(_carrier.global_position.x) >= 100.0:
		_end_play("touchdown")


func _check_tackles() -> void:
	if state == State.DEAD or _carrier == null or _carrier.action == Player.Action.DOWN:
		return
	for d in defense:
		if d.action == Player.Action.DOWN or d.tackle_cooldown > 0.0 or _block_system.is_locked(d):
			continue
		if d.global_position.distance_to(_carrier.global_position) > TACKLE_RADIUS:
			continue
		if _carrier.is_juking():
			d.tackle_cooldown = MISS_COOLDOWN
			continue
		_tackle(d)
		return


func _tackle(defender: Player) -> void:
	var sack := _carrier == _qb and play_type == PlayType.PASS
	defender.facing = (_carrier.global_position - defender.global_position).normalized()
	defender.knock_down(GET_UP_TIME)
	var downed_carrier := _carrier
	_end_play("sack" if sack else "tackle")
	downed_carrier.knock_down()


## Encerra a jogada, aplica as regras (downs, placar, relógio) e prepara a próxima formação.
func _end_play(result: String) -> void:
	var spot := rules.ball_on
	if result == "touchdown":
		spot = 100.0
	elif result != "incomplete":
		spot = _spot_from_x((_carrier if _carrier else _qb).global_position.x)
	var events: Dictionary
	var banner := ""
	if rules.next_play == GameRules.Next.TWO_POINT:
		events = rules.end_two_point(result == "touchdown")
		banner = "2-POINT GOOD!" if events["kick_good"] else "2-POINT FAILED"
	elif _in_return:
		events = rules.end_return(result, spot)
		banner = _banner_for(result, events)
	else:
		events = rules.end_play(result, spot)
		banner = _banner_for(result, events)
	_stop_everything(result, events, banner)


func _stop_everything(result: String, events: Dictionary, banner: String) -> void:
	state = State.DEAD
	play_result = result
	_dead_time = 0.0
	if _controller.controlled:
		_controller.controlled.input_dir = Vector2.ZERO
	_controller.enabled = false
	for runner in _runners:
		runner.stop()
	for p in offense + defense:
		p.input_dir = Vector2.ZERO
	_ball.height = 0.0
	_block_system.release_all()
	for p in offense + defense:
		p.speed_scale = 1.0
		p.shove = Vector2.ZERO
		p.block_pose = ""
	_show_message("FINAL" if events["game_over"] else banner)


func _banner_for(result: String, events: Dictionary) -> String:
	if events["touchdown"]:
		return "TOUCHDOWN!"
	if events["turnover"]:
		return "TURNOVER ON DOWNS"
	if events["first_down"]:
		return "1ST DOWN"
	if result == "incomplete":
		return "INCOMPLETE"
	if result == "sack":
		return "SACK"
	return ""


func _show_message(text: String) -> void:
	_message = text
	_message_time = MESSAGE_TIME


func _update_handoff() -> void:
	_ball.world_pos = _hands(_carrier)
	var to_qb := _qb.global_position - _rb.global_position
	_rb.input_dir = to_qb.normalized()
	_qb.input_dir = -to_qb.normalized()
	if to_qb.length() <= HANDOFF_DISTANCE:
		_take_control(_rb)
		_clear_time = CLEAR_TIME
		_clear_side = -attack_dir


## Durante o passe, enquadra o recebedor selecionado sem perder o QB de vista.
func _frame_pass() -> void:
	if human_side != Side.OFFENSE:
		return
	var half_width := get_viewport_rect().size.x / 2.0
	var gap := (_receivers[_target_index].global_position.x - _qb.global_position.x) * attack_dir
	camera.look_ahead.x = attack_dir * clampf(gap / 2.0, CAMERA_LOOK_AHEAD, half_width - CAMERA_QB_MARGIN)


## S troca o recebedor, D lança a bola.
func _pass_inputs() -> void:
	if human_side != Side.OFFENSE:
		return
	if Input.is_action_just_pressed("btn_s"):
		_set_target((_target_index + 1) % _receivers.size())
	if Input.is_action_just_pressed("btn_d"):
		_throw()


func _set_target(index: int) -> void:
	_target_index = index
	for i in _receivers.size():
		_receivers[i].is_pass_target = i == index


func _throw() -> void:
	var receiver := _receivers[_target_index]
	var from := _hands(_qb)
	var t := from.distance_to(receiver.global_position) / BALL_SPEED
	var aim := receiver.global_position
	for i in 3:  # passe com antecedência: mira onde o recebedor estará
		aim = receiver.global_position + receiver.velocity * t
		t = from.distance_to(aim) / BALL_SPEED
	aim.x = clampf(aim.x, 0.0, FieldConstants.yards_to_px(FieldConstants.TOTAL_YARDS))
	aim.y = clampf(aim.y, 0.0, FieldConstants.yards_to_px(FieldConstants.WIDTH_YARDS))
	_flight = PassFlight.new(from, aim, t, minf(40.0, from.distance_to(aim) * 0.25))
	_qb.input_dir = Vector2.ZERO
	_controller.enabled = false
	_carrier = null
	_anchor.global_position = from
	camera.look_ahead.x = attack_dir * CAMERA_LOOK_AHEAD
	camera.target = _anchor
	state = State.FLIGHT


func _update_flight(delta: float) -> void:
	_flight.advance(delta)
	_ball.world_pos = _flight.position()
	_ball.height = _flight.height()
	_anchor.global_position = _ball.world_pos
	if not _flight.finished():
		return
	_ball.height = 0.0
	var catcher := _nearest_of(_receivers, _flight.to, CATCH_RADIUS)
	if catcher:
		for i in _receivers.size():
			_runners[i].stop()
			_receivers[i].is_pass_target = false
		_take_control(catcher)
	else:
		_end_play("incomplete")


## Chute (punt, kickoff, field goal ou extra point): a bola voa até o ponto de queda ou até as traves.
func _launch_kick() -> void:
	var from := _hands(_kicker) if play_kind != PlayKind.KICKOFF else _ball.world_pos
	var center_y := FieldConstants.yards_to_px(FieldConstants.WIDTH_YARDS) / 2.0
	var field_end := FieldConstants.yards_to_px(FieldConstants.TOTAL_YARDS)
	var to: Vector2
	if play_kind == PlayKind.FIELD_GOAL or play_kind == PlayKind.EXTRA_POINT:
		_kick_good = rules.roll_field_goal()
		var miss_offset := 0.0 if _kick_good else (3.5 if rules.rng.randf() < 0.5 else -3.5)
		to = Vector2(FieldConstants.yard_line_to_x(100.0 if attack_dir > 0.0 else 0.0),
				center_y + FieldConstants.yards_to_px(miss_offset))
	else:
		var yards := rules.roll_kick_yards("kickoff" if play_kind == PlayKind.KICKOFF else "punt")
		var raw_x := from.x + attack_dir * FieldConstants.yards_to_px(yards)
		_kick_landing_spot = _spot_from_x(raw_x)
		to = Vector2(clampf(raw_x, 0.0, field_end),
				center_y + FieldConstants.yards_to_px(rules.rng.randf_range(-5.0, 5.0)))
		_kick_landing = to
		_begin_return_blocks()
	_flight = PassFlight.new(from, to, from.distance_to(to) / KICK_SPEED, minf(110.0, from.distance_to(to) * 0.25))
	_controller.enabled = false  # o retornador corre sozinho até o ponto de queda
	_anchor.global_position = from
	if human_side == Side.OFFENSE:
		camera.look_ahead.x = attack_dir * CAMERA_LOOK_AHEAD
		camera.target = _anchor
	state = State.KICK_FLIGHT


func _update_kick_flight(delta: float) -> void:
	_flight.advance(delta)
	_ball.world_pos = _flight.position()
	_ball.height = _flight.height()
	_anchor.global_position = _ball.world_pos
	if human_side == Side.OFFENSE:
		camera.target = _anchor
	if _flight.finished():
		_ball.height = 0.0
		_resolve_kick()


func _resolve_kick() -> void:
	var events: Dictionary
	match play_kind:
		PlayKind.FIELD_GOAL:
			events = rules.end_field_goal(_kick_good)
			_stop_everything("field_goal", events, "FIELD GOAL IS GOOD!" if _kick_good else "NO GOOD")
		PlayKind.EXTRA_POINT:
			events = rules.end_extra_point(_kick_good)
			_stop_everything("extra_point", events, "EXTRA POINT IS GOOD!" if _kick_good else "NO GOOD")
		_:
			var touchback_yard := GameRules.KICKOFF_TOUCHBACK_YARD if play_kind == PlayKind.KICKOFF \
					else GameRules.PUNT_TOUCHBACK_YARD
			var catcher := _nearest_of(defense, _kick_landing, KICK_CATCH_RADIUS)
			if _kick_landing_spot >= 100.0 or catcher == null:
				events = rules.end_kick_without_return(_kick_landing_spot, touchback_yard)
				_stop_everything("touchback" if events["touchback"] else "downed", events,
						"TOUCHBACK" if events["touchback"] else "DOWNED")
			else:
				_start_return(catcher)


## O time que recebeu pega a bola: ele passa a ser o ataque e o outro time vira a defesa (cobertura).
func _start_return(catcher: Player) -> void:
	rules.begin_return()
	var tmp := offense
	offense = defense
	defense = tmp
	attack_dir = -attack_dir
	human_side = Side.OFFENSE if rules.possession == HUMAN_TEAM else Side.DEFENSE
	_in_return = true
	if human_side == Side.DEFENSE:  # humano é o time que chutou: controla o jogador de cobertura mais próximo
		_controller.controlled = _nearest_of(defense, catcher.global_position, INF)
		_controller.enabled = true
	else:
		camera.look_ahead = Vector2(CAMERA_LOOK_AHEAD * attack_dir, 0.0)
	_take_control(catcher)


func _nearest_of(players: Array[Player], spot: Vector2, max_dist: float) -> Player:
	var best: Player = null
	var best_dist := max_dist
	for p in players:
		var d := p.global_position.distance_to(spot)
		if d <= best_dist:
			best = p
			best_dist = d
	return best


## O jogador passa a ser o portador. Com o humano no ataque, ele também passa a controlá-lo.
func _take_control(player: Player) -> void:
	_carrier = player
	player.pose = ""
	if human_side == Side.OFFENSE:
		_controller.controlled = player
		_controller.enabled = true
		camera.target = player
	player.downed.connect(_on_carrier_downed, CONNECT_ONE_SHOT)
	state = State.RUNNING


func _on_carrier_downed() -> void:
	if state != State.DEAD:
		_end_play("down")


## Monta a formação da próxima jogada. forced_kind: punt/field goal escolhidos no 4º down.
func _setup(forced_kind: PlayKind = PlayKind.SCRIMMAGE) -> void:
	for p in offense + defense:
		p.queue_free()
	_block_system.clear()
	for n in [_controller, _ball, _anchor]:
		if n:
			n.queue_free()

	play_kind = forced_kind
	match rules.next_play:
		GameRules.Next.KICKOFF:
			play_kind = PlayKind.KICKOFF
		GameRules.Next.EXTRA_POINT:
			play_kind = PlayKind.EXTRA_POINT
	attack_dir = 1.0 if rules.possession == 0 else -1.0
	human_side = Side.OFFENSE if rules.possession == HUMAN_TEAM else Side.DEFENSE
	var yard_line := rules.ball_on if attack_dir > 0.0 else 100.0 - rules.ball_on
	scrimmage_spot = Vector2(
			FieldConstants.yard_line_to_x(yard_line),
			FieldConstants.yards_to_px(FieldConstants.WIDTH_YARDS) / 2.0)

	var offense_team := Player.Team.A if rules.possession == 0 else Player.Team.B
	var defense_team := Player.Team.B if rules.possession == 0 else Player.Team.A
	var formations := _formations_for(play_kind)
	offense = _spawn(formations[0], offense_team, attack_dir)
	defense = _spawn(formations[1], defense_team, -attack_dir)
	_qb = _find(offense, "QB")
	_rb = _find(offense, "RB")
	_kicker = _find(offense, "K")
	_receivers.clear()
	_runners.clear()
	if play_kind == PlayKind.SCRIMMAGE:
		for role in Routes.TARGET_ORDER:
			var receiver := _find(offense, role)
			var runner := RouteRunner.new()
			receiver.add_child(runner)
			_receivers.append(receiver)
			_runners.append(runner)
	var ai_players := defense
	if play_kind in [PlayKind.KICKOFF, PlayKind.PUNT]:
		ai_players = offense + defense  # cobertura e retornador também têm IA
	for p in ai_players:
		var ai := DefenderAI.new()
		ai.match = self
		p.add_child(ai)
	_carrier = null
	_flight = null
	_in_return = false
	play_result = ""
	_defense_index = 0
	_presnap_time = DEFENSE_SNAP_DELAY
	_kick_countdown = 0.0
	state = State.PRE_SNAP

	_controller = HumanController.new()
	add_child(_controller)
	_controller.enabled = false
	if human_side == Side.OFFENSE:
		_controller.controlled = _kicker if play_kind != PlayKind.SCRIMMAGE else _qb
	else:
		_controller.controlled = defense[0]  # nos chutes, o primeiro da lista é o retornador

	_ball = Ball.new()
	_ball.world_pos = scrimmage_spot
	add_child(_ball)
	_anchor = Node2D.new()
	add_child(_anchor)
	_anchor.global_position = scrimmage_spot

	if camera:
		if human_side == Side.OFFENSE:
			camera.look_ahead = Vector2(CAMERA_LOOK_AHEAD * attack_dir, 0.0)
			camera.target = _controller.controlled
		else:
			camera.look_ahead = Vector2.ZERO
			camera.target = _anchor if play_kind == PlayKind.SCRIMMAGE else _controller.controlled
		camera.global_position = camera.target.global_position + camera.look_ahead
	_prompt = _prompt_text()


## Formações [time que chuta/ataca, time que recebe/defende] para o tipo de jogada.
func _formations_for(kind: PlayKind) -> Array:
	match kind:
		PlayKind.KICKOFF:
			return [Formation.KICKOFF_KICKING, Formation.KICKOFF_RECEIVING]
		PlayKind.PUNT:
			return [Formation.PUNT_KICKING, Formation.PUNT_RECEIVING]
		PlayKind.FIELD_GOAL, PlayKind.EXTRA_POINT:
			return [Formation.FIELD_GOAL_KICKING, Formation.FIELD_GOAL_DEFENSE]
	return [Formation.OFFENSE, Formation.DEFENSE]


## Dica de controle mostrada no HUD enquanto o humano escolhe a jogada.
func _prompt_text() -> String:
	if human_side != Side.OFFENSE or rules.game_over:
		return ""
	match play_kind:
		PlayKind.KICKOFF:
			return "A: KICKOFF"
		PlayKind.EXTRA_POINT:
			return "A: EXTRA POINT    BAIXO+A: 2 PONTOS" if rules.conversion_open else "A: CHUTAR"
		PlayKind.SCRIMMAGE:
			if rules.next_play == GameRules.Next.SCRIMMAGE and rules.down == 4:
				return "4o DOWN  BAIXO+A: PUNT  DIREITA+A: FG"
	return ""


## O QB sai para o lado oposto ao que o RB corta; sem corte, vai para a esquerda do ataque.
func _clear_qb(delta: float) -> void:
	if _clear_time <= 0.0:
		return
	_clear_time -= delta
	if absf(_rb.input_dir.y) > 0.3:
		_clear_side = -signf(_rb.input_dir.y)
	if _clear_time > 0.0:
		_qb.input_dir = Vector2(0.0, _clear_side)
	else:
		_qb.input_dir = Vector2.ZERO
		_qb.facing = Vector2(attack_dir, 0.0)


## Formações no referencial do ataque, giradas conforme a direção de ataque; a defesa usa os mesmos
## offsets do outro lado da bola.
func _spawn(slots: Array, team: Player.Team, facing_dir: float) -> Array[Player]:
	var players: Array[Player] = []
	for slot in slots:
		var player: Player = PLAYER_SCENE.instantiate()
		player.team = team
		player.role = slot["role"]
		player.attributes = PlayerAttributes.for_role(player.role)
		player.facing = Vector2(facing_dir, 0.0)
		player.pose = _pose_for(player.role)
		player.position = scrimmage_spot + slot["pos"] * attack_dir * FieldConstants.PX_PER_YARD
		add_child(player)
		players.append(player)
	return players


## Jardas da goal line do time com a bola (0 a 100) para uma coordenada X do campo.
func _spot_from_x(x: float) -> float:
	var yard_line := x / FieldConstants.PX_PER_YARD - FieldConstants.ENDZONE_YARDS
	return yard_line if attack_dir > 0.0 else 100.0 - yard_line


func _hands(player: Player) -> Vector2:
	# Bola junto ao corpo, na altura do peito; de frente/costas fica no lado do braço.
	var side := signf(player.facing.x) * 3.0
	if absf(player.facing.y) > absf(player.facing.x):
		side = 5.0
	return player.global_position + Vector2(side, -1)


func _pose_for(role: String) -> String:
	if role in STANCE_ROLES:
		return "stance"
	if role in START_ROLES:
		return "start"
	if role in READY_ROLES:
		return "ready"
	return ""


func _find(players: Array[Player], role: String) -> Player:
	for p in players:
		if p.role == role:
			return p
	return null
