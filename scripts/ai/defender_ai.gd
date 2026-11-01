class_name DefenderAI
extends Node
## IA mínima da defesa: vai em linha reta até o alvo que a partida indicar. Filho do Player.

const STOP_DISTANCE := 4.0

var match: Match


func _physics_process(_delta: float) -> void:
	var player := get_parent() as Player
	if player.is_controlled:
		return
	var target = match.defender_target(player.role)
	if target == null:
		player.input_dir = Vector2.ZERO
		return
	var to_target: Vector2 = target - player.global_position
	player.input_dir = to_target.normalized() if to_target.length() > STOP_DISTANCE else Vector2.ZERO
