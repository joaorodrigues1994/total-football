class_name BlockerAI
extends Node
## IA de bloqueio: vai até o defensor atribuído e fica entre ele e quem está com a bola. Filho do Player.

## Distância (px) entre o bloqueador e o defensor, do lado da bola.
const STAND_OFF := 13.0
const ARRIVE_DISTANCE := 3.0

var match: Match


func _physics_process(_delta: float) -> void:
	var player := get_parent() as Player
	if player.action == Player.Action.DOWN:
		return
	var job = match.block_job(player)
	if job == null:
		return
	var defender_pos: Vector2 = job["defender"].global_position
	var toward_ball: Vector2 = (job["protect"] - defender_pos).normalized()
	var to_spot: Vector2 = defender_pos + toward_ball * STAND_OFF - player.global_position
	player.input_dir = to_spot.normalized() if to_spot.length() > ARRIVE_DISTANCE else Vector2.ZERO
	if player.input_dir == Vector2.ZERO:
		player.facing = (defender_pos - player.global_position).normalized()
