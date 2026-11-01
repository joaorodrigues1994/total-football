class_name RouteRunner
extends Node
## IA de recebedor: percorre os pontos da rota e para no último. Filho do Player.

const ARRIVE_DISTANCE := 6.0

var active := false
var _points: Array[Vector2] = []
var _index := 0


func start(waypoints: Array, origin: Vector2, direction: float) -> void:
	_points.clear()
	for wp in waypoints:
		_points.append(origin + Vector2(wp.x * direction, wp.y) * FieldConstants.PX_PER_YARD)
	_index = 0
	active = true


func stop() -> void:
	active = false
	(get_parent() as Player).input_dir = Vector2.ZERO


func _physics_process(_delta: float) -> void:
	if not active:
		return
	var player := get_parent() as Player
	if _index >= _points.size():
		player.input_dir = Vector2.ZERO
		return
	var to_point := _points[_index] - player.global_position
	if to_point.length() <= ARRIVE_DISTANCE:
		_index += 1
		return
	player.input_dir = to_point.normalized()
