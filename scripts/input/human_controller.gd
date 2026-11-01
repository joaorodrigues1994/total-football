class_name HumanController
extends Node
## Lê os direcionais do teclado e os aplica ao jogador controlado.

@export var controlled: Player:
	set = set_controlled

## Desligado, o controlador não mexe no jogador (ex.: antes do snap e durante o handoff).
var enabled := true


func set_controlled(player: Player) -> void:
	if is_instance_valid(controlled):
		controlled.is_controlled = false
		controlled.input_dir = Vector2.ZERO
	controlled = player
	if controlled:
		controlled.is_controlled = true


func _physics_process(_delta: float) -> void:
	if controlled and enabled:
		controlled.input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
