class_name Player
extends CharacterBody2D
## Atleta em campo. Recebe uma direção desejada (input_dir) de um controlador (humano ou IA).

@export var attributes: PlayerAttributes
enum Team { A, B }
enum Action { NONE, JUKE, DIVE, DOWN }

const ACTION_ANIMS := {Action.JUKE: "juke_side", Action.DIVE: "dive_side", Action.DOWN: "lying_side"}
const JUKE_TIME := 0.3
const JUKE_COOLDOWN := 0.6
const DIVE_TIME := 0.2
const DIVE_YARDS := 2.0

## Emitido quando o jogador cai no chão para ficar (fim do pulo ou tackle sofrido).
signal downed

@export var team := Team.A
@export var role := ""
## Estado do jogador cadastrado nesta partida (identidade em state.data); null em jogadores sem cadastro.
var state: PlayerMatchState
## Uniforme e cor do marcador do time em campo (definidos pela partida); sem eles vale o visual antigo A/B.
var uniform_sheet: Texture2D
var marker_color := Color(0.0, 0.0, 0.0, 0.0)

## Indica (com o "P") que o jogador humano controla este atleta.
var is_controlled := false:
	set(value):
		is_controlled = value
		_marker.visible = value

## Direção desejada, definida por quem controla este jogador.
var input_dir := Vector2.ZERO
var facing := Vector2.RIGHT
## Pose de largada ("stance", "start", "ready") mostrada enquanto o jogador está parado.
var pose := ""

## Recebedor selecionado para o passe (mostra o triângulo amarelo).
var is_pass_target := false:
	set(value):
		is_pass_target = value
		_target_marker.visible = value

## Multiplicador de velocidade (menor que 1 enquanto o jogador está sendo bloqueado).
var speed_scale := 1.0

## Empurrão externo (px/s) somado ao movimento; usado nos confrontos de bloqueio.
var shove := Vector2.ZERO
## Pose de confronto ("block" ou "beaten") definida pelo sistema de bloqueio.
var block_pose := ""

## Tempo em que este defensor não pode tentar tackle (depois de errar um tackle).
var tackle_cooldown := 0.0

var action := Action.NONE
var _action_timer := 0.0
var _get_up_time := 0.0
var _juke_cooldown := 0.0
var _sprite := AnimatedSprite2D.new()
var _marker := ControlMarker.new()
var _target_marker := TargetMarker.new()


func _ready() -> void:
	if attributes == null:
		attributes = PlayerAttributes.new()
	var sheet: Texture2D = uniform_sheet
	if sheet == null:
		sheet = load("res://assets/sprites/player_team_%s.png" % ("a" if team == Team.A else "b"))
	_sprite.sprite_frames = PlayerSprites.build(sheet)
	_sprite.offset = Vector2(0, -2)
	if marker_color.a > 0.0:
		_marker.color = marker_color
	else:
		_marker.color = Color(0.35, 0.55, 1.0) if team == Team.A else Color(1.0, 0.35, 0.35)
	_marker.z_index = 10
	_marker.visible = is_controlled
	_sprite.add_child(_marker)
	_target_marker.z_index = 10
	_target_marker.visible = is_pass_target
	_sprite.add_child(_target_marker)
	add_child(_sprite)


func _process(_delta: float) -> void:
	# Só visual: desloca o sprite para acompanhar a perspectiva do campo.
	_sprite.position.x = FieldPerspective.project_x(
			global_position.x, global_position.y, FieldPerspective.camera_x(self)) - global_position.x


## Id do PlayerData; vazio se o jogador não vem de um elenco.
func player_id() -> String:
	return state.data.id if state else ""


## Finta: durante ela o portador escapa de tackles.
func try_juke() -> bool:
	if action != Action.NONE or _juke_cooldown > 0.0:
		return false
	action = Action.JUKE
	_action_timer = JUKE_TIME
	_juke_cooldown = JUKE_COOLDOWN
	return true


## Pulo para a frente: sem controle no ar; ao cair o jogador fica no chão.
func try_dive() -> bool:
	if action == Action.DIVE or action == Action.DOWN:
		return false
	action = Action.DIVE
	_action_timer = DIVE_TIME
	return true


## Derruba o jogador. Com get_up_time > 0 ele se levanta depois; sem, fica no chão (fim da jogada).
func knock_down(get_up_time := 0.0) -> void:
	action = Action.DOWN
	velocity = Vector2.ZERO
	_get_up_time = get_up_time
	if get_up_time <= 0.0:
		downed.emit()


func is_juking() -> bool:
	return action == Action.JUKE


func _physics_process(delta: float) -> void:
	_juke_cooldown = maxf(_juke_cooldown - delta, 0.0)
	tackle_cooldown = maxf(tackle_cooldown - delta, 0.0)
	if action == Action.DOWN:
		velocity = Vector2.ZERO
		if _get_up_time > 0.0:
			_get_up_time -= delta
			if _get_up_time <= 0.0:
				action = Action.NONE
		_update_animation()
		return
	if action == Action.DIVE:
		velocity = facing.normalized() * FieldConstants.yards_to_px(DIVE_YARDS) / DIVE_TIME
		move_and_slide()
		_action_timer -= delta
		if _action_timer <= 0.0:
			action = Action.DOWN
			velocity = Vector2.ZERO
			downed.emit()
		_update_animation()
		return
	if action == Action.JUKE:
		_action_timer -= delta
		if _action_timer <= 0.0:
			action = Action.NONE
	var dir := input_dir.limit_length(1.0)
	var max_speed := FieldConstants.yards_to_px(attributes.max_speed_yards()) * speed_scale
	var accel := FieldConstants.yards_to_px(attributes.acceleration_yards())
	velocity = velocity.move_toward(dir * max_speed, accel * delta)
	if dir != Vector2.ZERO:
		facing = dir.normalized()
	if shove != Vector2.ZERO:
		var own := velocity
		velocity += shove
		move_and_slide()
		velocity = own
	else:
		move_and_slide()
	position = position.clamp(Vector2.ZERO, Vector2(
		FieldConstants.yards_to_px(FieldConstants.TOTAL_YARDS),
		FieldConstants.yards_to_px(FieldConstants.WIDTH_YARDS)))
	_update_animation()


func _update_animation() -> void:
	if action != Action.NONE:
		_sprite.flip_h = facing.x < 0.0
		var anim: String = ACTION_ANIMS[action]
		if _sprite.animation != anim:
			_sprite.play(anim)
		return
	if block_pose != "":
		_sprite.flip_h = facing.x < 0.0
		_sprite.play(block_pose + "_side")
		return
	var view := "side"
	if absf(facing.y) > absf(facing.x):
		view = "down" if facing.y > 0.0 else "up"
	_sprite.flip_h = view == "side" and facing.x < 0.0
	var moving := velocity.length() > 10.0
	if pose != "" and not moving:
		_sprite.flip_h = facing.x < 0.0
		_sprite.play(pose + "_side")
		return
	var state := "run" if moving else "idle"
	_sprite.play("%s_%s" % [state, view])
