class_name Match
extends Node2D
## Monta a partida e conduz a jogada: formação, snap, handoff e corrida.

enum State { PRE_SNAP, SNAP, HANDOFF, RUNNING }

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const STANCE_ROLES := ["LT", "LG", "C", "RG", "RT", "TE", "LDE", "LDT", "RDT", "RDE"]
const START_ROLES := ["WR1", "WR2", "WR3"]
const READY_ROLES := ["RB"]
const SNAP_TIME := 0.3
const HANDOFF_DISTANCE := 18.0

@export var camera: MatchCamera
## Linha de jarda da bola (0 = goal line esquerda, 100 = direita).
@export var scrimmage_yard_line := 50.0

var state := State.PRE_SNAP
var offense: Array[Player] = []
var defense: Array[Player] = []
var scrimmage_spot := Vector2.ZERO

var _controller: HumanController
var _ball: Ball
var _qb: Player
var _rb: Player
var _carrier: Player
var _snap_progress := 0.0
var _snap_from := Vector2.ZERO


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
				_rb.pose = ""
				_snap_progress = 0.0
				_snap_from = _ball.world_pos
				state = State.SNAP
		State.SNAP:
			_snap_progress = minf(_snap_progress + delta / SNAP_TIME, 1.0)
			_ball.world_pos = _snap_from.lerp(_hands(_qb), _snap_progress)
			if _snap_progress >= 1.0:
				_carrier = _qb
				state = State.HANDOFF
		State.HANDOFF:
			_ball.world_pos = _hands(_carrier)
			var to_qb := _qb.global_position - _rb.global_position
			_rb.input_dir = to_qb.normalized()
			if to_qb.length() <= HANDOFF_DISTANCE:
				_carrier = _rb
				_controller.controlled = _rb
				_controller.enabled = true
				camera.target = _rb
				state = State.RUNNING
		State.RUNNING:
			_ball.world_pos = _hands(_carrier)


func _setup() -> void:
	for p in offense + defense:
		p.queue_free()
	if _controller:
		_controller.queue_free()
	if _ball:
		_ball.queue_free()

	offense = _spawn(Formation.OFFENSE, Player.Team.A, Vector2.RIGHT)
	defense = _spawn(Formation.DEFENSE, Player.Team.B, Vector2.LEFT)
	_qb = _find(offense, "QB")
	_rb = _find(offense, "RB")
	_carrier = null
	state = State.PRE_SNAP

	_controller = HumanController.new()
	add_child(_controller)
	_controller.enabled = false
	_controller.controlled = _qb

	_ball = Ball.new()
	_ball.world_pos = scrimmage_spot
	add_child(_ball)

	if camera:
		camera.target = _qb
		camera.global_position = _qb.global_position


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
	return player.global_position + player.facing * 6.0 + Vector2(0, 3)


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
