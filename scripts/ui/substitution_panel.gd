class_name SubstitutionPanel
extends CanvasLayer
## Painel de substituição sobre o menu de jogadas: vagas da escalação à esquerda, reservas compatíveis à direita.
## Só desenha; os dados vêm de SubstitutionController.info().

const PANEL := Rect2(16, 44, 480, 396)
const TEXT_COLOR := Color("e8e8f0")
const SELECTED_COLOR := Color("f2d230")
const DIM_COLOR := Color(0.6, 0.6, 0.7)

var _canvas := _Canvas.new()
var _info := {}


func _ready() -> void:
	layer = 6
	add_child(_canvas)
	visible = false


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
		var font := ThemeDB.fallback_font
		draw_rect(SubstitutionPanel.PANEL, Color(0.02, 0.03, 0.08, 0.95))
		draw_rect(Rect2(SubstitutionPanel.PANEL.position.x, SubstitutionPanel.PANEL.position.y, SubstitutionPanel.PANEL.size.x, 2),
				Color(0.85, 0.85, 0.95, 0.9))
		draw_string(font, Vector2(28, 66), "SUBSTITUTION", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, SubstitutionPanel.SELECTED_COLOR)
		var slots_active: bool = info["column"] == 0
		var rows: Array = info["rows"]
		for i in rows.size():
			var chosen: bool = i == info["slot_index"]
			var color: Color = SubstitutionPanel.SELECTED_COLOR if chosen else SubstitutionPanel.TEXT_COLOR
			if chosen and not slots_active:
				color = SubstitutionPanel.TEXT_COLOR
			draw_string(font, Vector2(28, 92 + i * 22), ("> " if chosen else "  ") + rows[i]["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)
		draw_string(font, Vector2(290, 80), "BENCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, SubstitutionPanel.DIM_COLOR)
		var bench: Array = info["bench"]
		if bench.is_empty():
			draw_string(font, Vector2(290, 100), "-", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, SubstitutionPanel.DIM_COLOR)
		for i in bench.size():
			var chosen: bool = i == info["bench_index"] and not slots_active
			draw_string(font, Vector2(290, 100 + i * 22), ("> " if chosen else "  ") + bench[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
					SubstitutionPanel.SELECTED_COLOR if chosen else SubstitutionPanel.TEXT_COLOR)
		if info["message"] != "":
			draw_string(font, Vector2(28, 392), info["message"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, SubstitutionPanel.SELECTED_COLOR)
		draw_string(font, Vector2(28, 426), "UP/DOWN: MOVE   RIGHT/A: BENCH   A: CONFIRM   LEFT: BACK   S/U: CLOSE",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, SubstitutionPanel.DIM_COLOR)
