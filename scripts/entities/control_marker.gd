class_name ControlMarker
extends Node2D
## Indicador "P" (com seta) sobre o jogador controlado, em pixel art.

const GLYPH_P := ["XXXX.", "X...X", "X...X", "XXXX.", "X....", "X....", "X...."]
const GLYPH_ARROW := ["XXXXX", ".XXX.", "..X.."]

var color := Color.WHITE


func _draw() -> void:
	var rows := GLYPH_P + [""] + GLYPH_ARROW
	var origin := Vector2(-2, -24)
	for pass_index in 2:
		for r in rows.size():
			var row: String = rows[r]
			for c in row.length():
				if row[c] != "X":
					continue
				var at := origin + Vector2(c, r)
				if pass_index == 0:
					draw_rect(Rect2(at - Vector2.ONE, Vector2(3, 3)), Color.WHITE)
				else:
					draw_rect(Rect2(at, Vector2.ONE), color)
