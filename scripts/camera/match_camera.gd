class_name MatchCamera
extends Camera2D
## Câmera que acompanha um alvo (a bola) dentro dos limites do campo.

@export var target: Node2D
@export var follow_speed := 8.0
## Deslocamento do foco em relação ao alvo (ex.: mostrar mais campo à frente do ataque).
var look_ahead := Vector2.ZERO


func _ready() -> void:
	limit_left = 0
	limit_top = 0
	limit_right = int(FieldConstants.yards_to_px(FieldConstants.TOTAL_YARDS))
	limit_bottom = int(FieldConstants.yards_to_px(FieldConstants.WIDTH_YARDS))
	if target:
		global_position = target.global_position + look_ahead


func _process(delta: float) -> void:
	if target:
		global_position = global_position.lerp(target.global_position + look_ahead, clampf(follow_speed * delta, 0.0, 1.0))
