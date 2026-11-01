class_name InputSetup
extends RefCounted
## Registra as ações de teclado do jogo (A, S, D), timeout (T), punt (P), field goal (G) e as teclas temporárias de reset (R) e de trocar ataque/defesa (Y).

const KEYS := {
	"btn_a": KEY_A,
	"btn_s": KEY_S,
	"btn_d": KEY_D,
	"debug_reset": KEY_R,
	"debug_swap_side": KEY_Y,
	"btn_timeout": KEY_T,
	"btn_punt": KEY_P,
	"btn_fg": KEY_G,
}


static func ensure() -> void:
	for action in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = KEYS[action]
		InputMap.action_add_event(action, ev)
