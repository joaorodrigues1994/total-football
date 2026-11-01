extends Node2D
## TEMPORÁRIO: marcador movido pelas setas só para validar a câmera. Será removido quando a bola existir.

const SPEED := 240.0


func _process(delta: float) -> void:
	position += Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") * SPEED * delta
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 6.0, Color("e8b04a"))
