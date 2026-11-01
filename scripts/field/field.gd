class_name Field
extends Node2D
## Desenha o campo horizontal: grama, endzones, linhas de jarda e números.

const GRASS_A := Color("2f7d32")
const GRASS_B := Color("2a712d")
const ENDZONE_LEFT := Color("1f4e8c")
const ENDZONE_RIGHT := Color("8c1f2a")
const LINE := Color("f2f2f2")


func _draw() -> void:
	var h := FieldConstants.yards_to_px(FieldConstants.WIDTH_YARDS)
	var total_w := FieldConstants.yards_to_px(FieldConstants.TOTAL_YARDS)

	# Faixas de grama a cada 5 jardas.
	for i in int(FieldConstants.TOTAL_YARDS / 5.0):
		var x := FieldConstants.yards_to_px(i * 5.0)
		draw_rect(Rect2(x, 0, FieldConstants.yards_to_px(5.0), h), GRASS_A if i % 2 == 0 else GRASS_B)

	var ez_w := FieldConstants.yards_to_px(FieldConstants.ENDZONE_YARDS)
	draw_rect(Rect2(0, 0, ez_w, h), ENDZONE_LEFT)
	draw_rect(Rect2(total_w - ez_w, 0, ez_w, h), ENDZONE_RIGHT)

	# Linhas de 5 em 5 jardas (as de 10 são mais grossas e numeradas).
	var font := ThemeDB.fallback_font
	for yl in range(0, 101, 5):
		var x := FieldConstants.yard_line_to_x(yl)
		var major := yl % 10 == 0
		draw_line(Vector2(x, 0), Vector2(x, h), LINE, 3.0 if major else 1.5)
		if major and yl > 0 and yl < 100:
			var n := str(mini(yl, 100 - yl))
			var size := font.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
			draw_string(font, Vector2(x - size.x / 2.0, h * 0.2), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, LINE)
			draw_string(font, Vector2(x - size.x / 2.0, h * 0.85), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, LINE)

	# Hash marks.
	for yl in range(1, 100):
		var x := FieldConstants.yard_line_to_x(yl)
		for y in [h * 0.4, h * 0.6]:
			draw_line(Vector2(x, y - 3), Vector2(x, y + 3), LINE, 1.0)

	# Bordas.
	draw_rect(Rect2(0, 0, total_w, h), LINE, false, 3.0)
