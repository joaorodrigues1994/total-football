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
		_points.append(origin + Vector2(wp.x, wp.y) * direction * FieldConstants.PX_PER_YARD)
	_index = 0
	active = true


func stop() -> void:
	active = false
	(get_parent() as Player).input_dir = Vector2.ZERO


## Onde o recebedor estará daqui a `seconds` seguindo a rota restante na velocidade dada (px/s). Só leitura.
func position_after(seconds: float, speed: float) -> Vector2:
	var player := get_parent() as Player
	var pos := player.global_position
	if not active:
		return pos + player.velocity * seconds
	var left := speed * seconds
	for i in range(_index, _points.size()):
		var leg := pos.distance_to(_points[i])
		if leg >= left:
			return pos.move_toward(_points[i], left)
		left -= leg
		pos = _points[i]
	return pos


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
