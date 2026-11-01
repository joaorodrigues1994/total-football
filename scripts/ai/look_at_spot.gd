class_name LookAtSpot
extends Node
## IA mínima: jogador parado e não controlado fica virado para um ponto (a linha de scrimmage).
## Filho do Player, para rodar depois dele no frame.

var spot := Vector2.ZERO


func _physics_process(_delta: float) -> void:
	var player := get_parent() as Player
	if player.is_controlled or player.velocity.length() > 1.0:
		return
	var to_spot := spot - player.global_position
	if to_spot.length() > 1.0:
		player.facing = to_spot.normalized()
