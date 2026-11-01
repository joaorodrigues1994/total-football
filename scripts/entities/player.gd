class_name Player
extends CharacterBody2D
## Atleta em campo. Recebe uma direção desejada (input_dir) de um controlador (humano ou IA).

@export var attributes: PlayerAttributes
@export var team_color := Color("1f4e8c")

## Direção desejada, definida por quem controla este jogador.
var input_dir := Vector2.ZERO
var facing := Vector2.RIGHT


func _ready() -> void:
	if attributes == null:
		attributes = PlayerAttributes.new()


func _physics_process(delta: float) -> void:
	var dir := input_dir.limit_length(1.0)
	var max_speed := FieldConstants.yards_to_px(attributes.max_speed_yards())
	var accel := FieldConstants.yards_to_px(attributes.acceleration_yards())
	velocity = velocity.move_toward(dir * max_speed, accel * delta)
	if dir != Vector2.ZERO:
		facing = dir.normalized()
	move_and_slide()
	position = position.clamp(Vector2.ZERO, Vector2(
		FieldConstants.yards_to_px(FieldConstants.TOTAL_YARDS),
		FieldConstants.yards_to_px(FieldConstants.WIDTH_YARDS)))
	queue_redraw()


# Visual provisório (substituído pelos sprites do LibreSprite na etapa 3).
func _draw() -> void:
	draw_circle(Vector2.ZERO, 7.0, team_color)
	draw_line(Vector2.ZERO, facing * 10.0, Color.WHITE, 2.0)
