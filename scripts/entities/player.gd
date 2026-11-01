class_name Player
extends CharacterBody2D
## Atleta em campo. Recebe uma direção desejada (input_dir) de um controlador (humano ou IA).

@export var attributes: PlayerAttributes
enum Team { A, B }

@export var team := Team.A

## Direção desejada, definida por quem controla este jogador.
var input_dir := Vector2.ZERO
var facing := Vector2.RIGHT

var _sprite := AnimatedSprite2D.new()


func _ready() -> void:
	if attributes == null:
		attributes = PlayerAttributes.new()
	var sheet: Texture2D = load("res://assets/sprites/player_team_%s.png" % ("a" if team == Team.A else "b"))
	_sprite.sprite_frames = PlayerSprites.build(sheet)
	_sprite.offset = Vector2(0, -2)
	add_child(_sprite)


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
	_update_animation()


func _update_animation() -> void:
	var view := "side"
	if absf(facing.y) > absf(facing.x):
		view = "down" if facing.y > 0.0 else "up"
	_sprite.flip_h = view == "side" and facing.x < 0.0
	var state := "run" if velocity.length() > 10.0 else "idle"
	_sprite.play("%s_%s" % [state, view])
