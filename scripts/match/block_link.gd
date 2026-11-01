class_name BlockLink
extends RefCounted
## Um confronto de bloqueio: um bloqueador contra um defensor, com o estado atual da disputa.

enum State { MOVING_TO_TARGET, ENGAGING, BLOCKING, FIGHTING_BLOCK, LOSING_BLOCK, BLOCK_BROKEN, RECOVERING }

var blocker: Player
var defender: Player
var state := State.MOVING_TO_TARGET
var time_in_state := 0.0
## Atraso antes de sair (esquema) e tempo máximo segurando o bloqueio.
var delay := 0.0
var duration := 3.0
## Direção de empurrão em campo (Vector2) ou "away" (para fora do portador/QB).
var drive: Variant = Vector2.ZERO
## Domínio do bloqueador: 1 = domina, 0 = rompido.
var grip := 0.0
var contest_timer := 0.0
var held := 0.0
var recover_time := 0.0
var retarget_timer := 0.0
## Teto e desgaste extra do domínio (retornos): ninguém segura a cobertura indefinidamente.
var grip_cap := 1.0
var extra_decay := 0.0


func set_state(new_state: State) -> void:
	state = new_state
	time_in_state = 0.0


func is_engaged() -> bool:
	return state in [State.ENGAGING, State.BLOCKING, State.FIGHTING_BLOCK, State.LOSING_BLOCK]
