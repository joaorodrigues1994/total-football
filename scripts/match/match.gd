class_name Match
extends Node2D
## Monta a partida e conduz a jogada: formação, snap, corrida (handoff) e passe.

enum State { PRE_SNAP, SNAP, HANDOFF, DROPBACK, PASSING, FLIGHT, RUNNING, DEAD }
enum PlayType { RUN, PASS }

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const STANCE_ROLES := ["LT", "LG", "C", "RG", "RT", "TE", "LDE", "LDT", "RDT", "RDE"]
const START_ROLES := ["WR1", "WR2", "WR3"]
const READY_ROLES := ["RB"]
const SNAP_TIME := 0.3
const HANDOFF_DISTANCE := 18.0
## Depois da entrega o QB sai lateralmente da frente do RB por este tempo.
const CLEAR_TIME := 0.7
const DROPBACK_YARDS := 5.0
const BALL_SPEED := 360.0
const CATCH_RADIUS := 20.0
## O ataque (virado para a direita) fica deslocado para a esquerda da tela, mostrando mais campo à frente.
const CAMERA_LOOK_AHEAD := 100.0
## Margem mínima (px) entre o QB e a borda da tela durante o passe.
const CAMERA_QB_MARGIN := 48.0

@export var camera: MatchCamera
## Linha de jarda da bola (0 = goal line esquerda, 100 = direita).
@export var scrimmage_yard_line := 50.0

var state := State.PRE_SNAP
var play_type := PlayType.RUN
var offense: Array[Player] = []
var defense: Array[Player] = []
var scrimmage_spot := Vector2.ZERO

var _controller: HumanController
var _ball: Ball
var _anchor: Node2D
var _qb: Player
var _rb: Player
var _carrier: Player
var _receivers: Array[Player] = []
var _runners: Array[RouteRunner] = []
var _target_index := 0
var _flight: PassFlight
var _snap_progress := 0.0
var _snap_from := Vector2.ZERO
var _clear_time := 0.0
var _clear_side := -1.0
var _dropback_x := 0.0


func _ready() -> void:
	InputSetup.ensure()
	scrimmage_spot = Vector2(
			FieldConstants.yard_line_to_x(scrimmage_yard_line),
			FieldConstants.yards_to_px(FieldConstants.WIDTH_YARDS) / 2.0)
	_setup()


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("debug_reset"):  # TEMPORÁRIO: some quando existirem os tackles.
		_setup()
		return
	match state:
		State.PRE_SNAP:
			if Input.is_action_just_pressed("btn_a"):
				_start_play()
		State.SNAP:
			_snap_progress = minf(_snap_progress + delta / SNAP_TIME, 1.0)
			_ball.world_pos = _snap_from.lerp(_hands(_qb), _snap_progress)
			if _snap_progress >= 1.0:
				_carrier = _qb
				state = State.HANDOFF if play_type == PlayType.RUN else State.DROPBACK
				_dropback_x = _qb.global_position.x - FieldConstants.yards_to_px(DROPBACK_YARDS)
		State.HANDOFF:
			_update_handoff()
		State.DROPBACK:
			_ball.world_pos = _hands(_qb)
			_frame_pass()
			_pass_inputs()
			if state == State.DROPBACK:
				_qb.input_dir = Vector2.LEFT
				if _qb.global_position.x <= _dropback_x:
					_qb.input_dir = Vector2.ZERO
					_qb.facing = Vector2.RIGHT
					_controller.controlled = _qb
					_controller.enabled = true
					state = State.PASSING
		State.PASSING:
			_ball.world_pos = _hands(_qb)
			_frame_pass()
			_pass_inputs()
		State.FLIGHT:
			_update_flight(delta)
		State.RUNNING:
			_ball.world_pos = _hands(_carrier)
			_clear_qb(delta)
			if Input.is_action_just_pressed("btn_s"):
				_carrier.try_juke()
			if Input.is_action_just_pressed("btn_d"):
				_carrier.try_dive()
		State.DEAD:
			if _carrier:
				_ball.world_pos = _hands(_carrier)
			_clear_qb(delta)


func _start_play() -> void:
	play_type = PlayType.PASS if Input.is_action_pressed("ui_left") else PlayType.RUN
	_rb.pose = ""
	_snap_progress = 0.0
	_snap_from = _ball.world_pos
	state = State.SNAP
	if play_type == PlayType.PASS:
		for i in _receivers.size():
			var p := _receivers[i]
			p.pose = ""
			_runners[i].start(Routes.PASS_TEST[p.role], p.global_position, 1.0)
		_set_target(0)


## Durante o passe, enquadra o recebedor selecionado sem perder o QB de vista.
func _frame_pass() -> void:
	var half_width := get_viewport_rect().size.x / 2.0
	var gap := _receivers[_target_index].global_position.x - _qb.global_position.x
	camera.look_ahead.x = clampf(gap / 2.0, CAMERA_LOOK_AHEAD, half_width - CAMERA_QB_MARGIN)


func _update_handoff() -> void:
	_ball.world_pos = _hands(_carrier)
	var to_qb := _qb.global_position - _rb.global_position
	_rb.input_dir = to_qb.normalized()
	_qb.input_dir = -to_qb.normalized()
	if to_qb.length() <= HANDOFF_DISTANCE:
		_take_control(_rb)
		_clear_time = CLEAR_TIME
		_clear_side = -1.0


## S troca o recebedor, D lança a bola.
func _pass_inputs() -> void:
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
	_anchor.global_position = from
	camera.look_ahead.x = CAMERA_LOOK_AHEAD
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
	var catcher := _nearest_receiver(_flight.to)
	if catcher:
		for i in _receivers.size():
			_runners[i].stop()
			_receivers[i].is_pass_target = false
		_take_control(catcher)
	else:
		_carrier = null
		state = State.DEAD  # passe incompleto


func _nearest_receiver(spot: Vector2) -> Player:
	var best: Player = null
	var best_dist := CATCH_RADIUS
	for p in _receivers:
		var d := p.global_position.distance_to(spot)
		if d <= best_dist:
			best = p
			best_dist = d
	return best


## O jogador passa a ser o portador controlado pelo humano.
func _take_control(player: Player) -> void:
	_carrier = player
	player.pose = ""
	_controller.controlled = player
	_controller.enabled = true
	camera.target = player
	player.downed.connect(_on_carrier_downed, CONNECT_ONE_SHOT)
	state = State.RUNNING


func _on_carrier_downed() -> void:
	state = State.DEAD
	_controller.enabled = false


func _setup() -> void:
	for p in offense + defense:
		p.queue_free()
	for n in [_controller, _ball, _anchor]:
		if n:
			n.queue_free()

	offense = _spawn(Formation.OFFENSE, Player.Team.A, Vector2.RIGHT)
	defense = _spawn(Formation.DEFENSE, Player.Team.B, Vector2.LEFT)
	_qb = _find(offense, "QB")
	_rb = _find(offense, "RB")
	_receivers.clear()
	_runners.clear()
	for role in Routes.TARGET_ORDER:
		var receiver := _find(offense, role)
		var runner := RouteRunner.new()
		receiver.add_child(runner)
		_receivers.append(receiver)
		_runners.append(runner)
	_carrier = null
	_flight = null
	state = State.PRE_SNAP

	_controller = HumanController.new()
	add_child(_controller)
	_controller.enabled = false
	_controller.controlled = _qb

	_ball = Ball.new()
	_ball.world_pos = scrimmage_spot
	add_child(_ball)
	_anchor = Node2D.new()
	add_child(_anchor)

	if camera:
		camera.look_ahead = Vector2(CAMERA_LOOK_AHEAD, 0.0)
		camera.target = _qb
		camera.global_position = _qb.global_position + camera.look_ahead


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
		_qb.facing = Vector2.RIGHT


## Time atacando para a direita; a defesa usa os mesmos offsets do outro lado da bola.
func _spawn(slots: Array, team: Player.Team, facing: Vector2) -> Array[Player]:
	var players: Array[Player] = []
	for slot in slots:
		var player: Player = PLAYER_SCENE.instantiate()
		player.team = team
		player.role = slot["role"]
		player.facing = facing
		player.pose = _pose_for(player.role)
		player.position = scrimmage_spot + slot["pos"] * FieldConstants.PX_PER_YARD
		add_child(player)
		players.append(player)
	return players


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
