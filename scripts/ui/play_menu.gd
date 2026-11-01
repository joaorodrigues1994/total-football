class_name PlayMenu
extends CanvasLayer
## Menu de seleção de jogadas: painel compacto na base da tela com as 4 direções de cada grupo
## (A = terrestre / contra corrida, S = aérea / contra passe), play clock e timeouts.
## Só desenha; quem decide é o Match.

const PANEL := Rect2(0, 330, 512, 118)
const CENTERS := {"a": Vector2(130, 402), "s": Vector2(382, 402)}
const OFFSETS := {
	"up": Vector2(-24, -22), "down": Vector2(-24, 30), "left": Vector2(-104, 4), "right": Vector2(34, 4),
}
const TAGS := {"up": "UP", "down": "DN", "left": "LT", "right": "RT"}
const WARNING_COLOR := Color("ff4040")
const SELECTED_COLOR := Color("f2d230")
const TEXT_COLOR := Color("e8e8f0")

var _canvas := _Canvas.new()
var _info := {}


func _ready() -> void:
	layer = 5
	add_child(_canvas)
	visible = false


## info: visible, offense (bool), plays (Dictionary do Playbook), selected (chave da jogada escolhida),
## seconds, warning, timeouts, fourth_down, can_timeout.
func refresh(info: Dictionary) -> void:
	visible = info["visible"]
	if info != _info:
		_info = info.duplicate()
		_canvas.info = _info
		_canvas.queue_redraw()


class _Canvas extends Control:
	var info := {}

	func _ready() -> void:
		size = Vector2(512, 448)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if info.is_empty():
			return
		draw_rect(PlayMenu.PANEL, Color(0.02, 0.03, 0.08, 0.82))
		draw_rect(Rect2(0, PlayMenu.PANEL.position.y, 512, 2), Color(0.85, 0.85, 0.95, 0.9))
		var font := ThemeDB.fallback_font
		var title := "OFFENSE - SELECT PLAY" if info["offense"] else "DEFENSE - SELECT PLAY"
		draw_string(font, Vector2(8, 348), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PlayMenu.TEXT_COLOR)
		var clock_color: Color = PlayMenu.WARNING_COLOR if info["warning"] else PlayMenu.TEXT_COLOR
		draw_string(font, Vector2(380, 348), "PLAY CLOCK %02d" % info["seconds"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, clock_color)
		var to: Array = info["timeouts"]
		draw_string(font, Vector2(8, 442), "T: TIMEOUT   A:%d B:%d" % [to[0], to[1]], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, PlayMenu.TEXT_COLOR)
		if info["fourth_down"]:
			draw_string(font, Vector2(190, 442), "P: PUNT   G: FIELD GOAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, PlayMenu.SELECTED_COLOR)
		var heads := {"a": "RUN" if info["offense"] else "RUN DEFENSE", "s": "PASS" if info["offense"] else "PASS DEFENSE"}
		var buttons := {"a": "A", "s": "S"}
		for group in PlayMenu.CENTERS:
			var c: Vector2 = PlayMenu.CENTERS[group]
			draw_string(font, Vector2(c.x - 40, 362), "%s + DIRECTION: %s" % [buttons[group], heads[group]],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 9, PlayMenu.TEXT_COLOR)
			for dir in PlayMenu.OFFSETS:
				var key := "%s_%s" % [dir, group]
				var play: Dictionary = info["plays"][key]
				var color: Color = PlayMenu.SELECTED_COLOR if key == info["selected"] else PlayMenu.TEXT_COLOR
				draw_string(font, c + PlayMenu.OFFSETS[dir], "%s %s" % [PlayMenu.TAGS[dir], play["name"]],
						HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)
		if info.get("kick_label", "") != "":
			draw_string(font, Vector2(0, 348), "READY: %s" % info["kick_label"], HORIZONTAL_ALIGNMENT_CENTER, 512, 11, PlayMenu.SELECTED_COLOR)
		if info["selected"] != "":
			var chosen: Dictionary = info["plays"][info["selected"]]
			draw_string(font, Vector2(0, 348), "READY: %s" % chosen["name"], HORIZONTAL_ALIGNMENT_CENTER, 512, 11, PlayMenu.SELECTED_COLOR)
