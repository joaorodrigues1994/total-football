class_name BreakEffect
extends Node2D
## Efeito curto quando um defensor rompe o bloqueio: pequeno estouro de linhas.

const LIFETIME := 0.3
const RAYS := 8

var world_pos := Vector2.ZERO
var _age := 0.0


func _ready() -> void:
	z_index = 10
	_place()


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	_place()
	queue_redraw()


func _place() -> void:
	# Mesma perspectiva visual dos sprites.
	position = Vector2(FieldPerspective.project_x(world_pos.x, world_pos.y, FieldPerspective.camera_x(self)),
			world_pos.y - 8.0)


func _draw() -> void:
	var t := _age / LIFETIME
	var inner := 3.0 + 7.0 * t
	var color := Color(1.0, 0.95, 0.6, 1.0 - t)
	for i in RAYS:
		var dir := Vector2.from_angle(TAU * i / RAYS)
		draw_line(dir * inner, dir * (inner + 4.0), color, 1.0)
