class_name Ball
extends Node2D
## Bola. Posição de jogo em world_pos (plano); a posição na tela segue a perspectiva do campo.

var world_pos := Vector2.ZERO
## Altura (px) acima do chão, usada nos passes.
var height := 0.0

const BROWN := Color("8a4b1f")
const BROWN_LIGHT := Color("b8702f")


func _ready() -> void:
	z_index = 5


func _process(_delta: float) -> void:
	position = Vector2(
			FieldPerspective.project_x(world_pos.x, world_pos.y, FieldPerspective.camera_x(self)),
			world_pos.y - height)
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.62))
	draw_circle(Vector2.ZERO, 5.0, Color(0.06, 0.06, 0.09))
	draw_circle(Vector2.ZERO, 4.0, BROWN)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_line(Vector2(-2, -1), Vector2(2, -1), Color.WHITE, 1.0)
	draw_line(Vector2(-3, 0), Vector2(3, 0), BROWN_LIGHT, 1.0)
