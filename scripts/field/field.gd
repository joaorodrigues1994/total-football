class_name Field
extends Node2D
## Desenha o campo horizontal com perspectiva inclinada: grama, endzones, linhas de jarda e números.

const GRASS_A := Color("3a8f3d")
const GRASS_B := Color("327f35")
const ENDZONE_LEFT := Color("1f4e8c")
const ENDZONE_RIGHT := Color("8c1f2a")
const LINE := Color("f2f2f2")
const SCRIMMAGE_LINE := Color("e02020")
const FIRST_DOWN_LINE := Color("f2d230")

## Posição x (px) das linhas de scrimmage e de first down; negativo = escondida. Definidas pela partida.
var scrimmage_x := -1.0
var first_down_x := -1.0

var _grass_noise: Texture2D = load("res://assets/field/grass_noise.png")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var cx := FieldPerspective.camera_x(self)
	var h := FieldConstants.yards_to_px(FieldConstants.WIDTH_YARDS)
	var total_w := FieldConstants.yards_to_px(FieldConstants.TOTAL_YARDS)

	# Faixas de grama a cada 5 jardas.
	for i in int(FieldConstants.TOTAL_YARDS / 5.0):
		var x := FieldConstants.yards_to_px(i * 5.0)
		_quad(cx, x, x + FieldConstants.yards_to_px(5.0), h, GRASS_A if i % 2 == 0 else GRASS_B)

	var ez_w := FieldConstants.yards_to_px(FieldConstants.ENDZONE_YARDS)
	_quad(cx, 0.0, ez_w, h, ENDZONE_LEFT)
	_quad(cx, total_w - ez_w, total_w, h, ENDZONE_RIGHT)

	# Textura pontilhada da grama por cima das cores.
	var x0 := maxf(0.0, cx - 420.0)
	var x1 := minf(total_w, cx + 420.0)
	draw_texture_rect(_grass_noise, Rect2(x0, 0.0, x1 - x0, h), true)

	# Linhas de 5 em 5 jardas (as de 10 são mais grossas e numeradas).
	var font := ThemeDB.fallback_font
	for yl in range(0, 101, 5):
		var x := FieldConstants.yard_line_to_x(yl)
		var major := yl % 10 == 0
		draw_line(_p(cx, x, 0.0), _p(cx, x, h), LINE, 3.0 if major else 1.5)
		if major and yl > 0 and yl < 100:
			var n := str(mini(yl, 100 - yl))
			var size := font.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
			for y in [h * 0.2, h * 0.85]:
				var at := _p(cx, x, y)
				draw_string(font, Vector2(at.x - size.x / 2.0, at.y), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, LINE)

	# Linha de scrimmage (vermelha) e de first down (amarela).
	for marker in [[first_down_x, FIRST_DOWN_LINE], [scrimmage_x, SCRIMMAGE_LINE]]:
		if marker[0] >= 0.0:
			draw_line(_p(cx, marker[0], 0.0), _p(cx, marker[0], h), marker[1], 3.0)

	# Hash marks.
	for yl in range(1, 100):
		var x := FieldConstants.yard_line_to_x(yl)
		for y in [h * 0.4, h * 0.6]:
			var at := _p(cx, x, y)
			draw_line(at - Vector2(0, 3), at + Vector2(0, 3), LINE, 1.0)

	# Bordas.
	var border := PackedVector2Array([_p(cx, 0.0, 0.0), _p(cx, total_w, 0.0),
		_p(cx, total_w, h), _p(cx, 0.0, h), _p(cx, 0.0, 0.0)])
	draw_polyline(border, LINE, 3.0)


func _p(cx: float, x: float, y: float) -> Vector2:
	return Vector2(FieldPerspective.project_x(x, y, cx), y)


func _quad(cx: float, x0: float, x1: float, h: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([_p(cx, x0, 0.0), _p(cx, x1, 0.0), _p(cx, x1, h), _p(cx, x0, h)]), color)
