class_name Match
extends Node2D
## Monta a partida: posiciona os 22 jogadores em formação na linha de scrimmage.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const STANCE_ROLES := ["LT", "LG", "C", "RG", "RT", "TE", "LDE", "LDT", "RDT", "RDE"]
const START_ROLES := ["WR1", "WR2", "WR3"]
const READY_ROLES := ["RB"]

@export var camera: MatchCamera
## Linha de jarda da bola (0 = goal line esquerda, 100 = direita).
@export var scrimmage_yard_line := 50.0

var offense: Array[Player] = []
var defense: Array[Player] = []
var scrimmage_spot := Vector2.ZERO


func _ready() -> void:
	scrimmage_spot = Vector2(
			FieldConstants.yard_line_to_x(scrimmage_yard_line),
			FieldConstants.yards_to_px(FieldConstants.WIDTH_YARDS) / 2.0)
	offense = _spawn(Formation.OFFENSE, Player.Team.A, Vector2.RIGHT)
	defense = _spawn(Formation.DEFENSE, Player.Team.B, Vector2.LEFT)

	var qb := _find(offense, "QB")
	var controller := HumanController.new()
	controller.controlled = qb
	add_child(controller)
	if camera:
		camera.target = qb
		camera.global_position = qb.global_position


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
