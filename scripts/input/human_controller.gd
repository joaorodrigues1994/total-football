class_name HumanController
extends Node
## Lê os direcionais do teclado e os aplica ao jogador controlado.

@export var controlled: Player


func _physics_process(_delta: float) -> void:
	if controlled:
		controlled.input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
