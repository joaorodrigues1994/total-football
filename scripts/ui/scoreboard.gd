class_name Scoreboard
extends CanvasLayer
## Placar compacto no topo (placar, quarto, tempo, down e distância, posse, timeouts), banner de eventos
## e telas simples de fim de quarto e fim de jogo. Só desenha; os dados vêm de GameRules.

const BAR_HEIGHT := 32.0
const TEAM_COLORS := [Color(0.12, 0.31, 0.55), Color(0.55, 0.12, 0.17)]
const TEXT_COLOR := Color("e8e8f0")
const ACCENT_COLOR := Color("f2d230")

var _bar := _Bar.new()
var _banner := Label.new()
var _overlay_time := 0.0
var _overlay_title := ""
var _overlay_sub := ""


func _ready() -> void:
	layer = 4
	add_child(_bar)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 4)
	_banner.position = Vector2(0, 42)
	_banner.size = Vector2(512, 28)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 20)
	_banner.add_theme_color_override("font_color", ACCENT_COLOR)
	add_child(_banner)


func _process(delta: float) -> void:
	if _overlay_time > 0.0:
		_overlay_time -= delta
		if _overlay_time <= 0.0:
			_bar.overlay_title = ""
			_bar.queue_redraw()


func show_rules(rules: GameRules, banner: String) -> void:
	var data := {
		"score": rules.score.duplicate(),
		"quarter": "FINAL" if rules.game_over else "Q%d" % rules.quarter,
		"clock": rules.clock_text(),
		"situation": rules.down_and_distance(),
		"possession": rules.possession,
		"ball": _ball_text(rules),
		"timeouts": rules.timeouts.duplicate(),
		"game_over": rules.game_over,
	}
	_banner.text = banner
	if data != _bar.data:
		_bar.data = data
		if rules.game_over:
			show_overlay("FINAL", "A %d  x  B %d" % [rules.score[0], rules.score[1]], 0.0)
		_bar.queue_redraw()


## Tela simples sobre o campo. seconds <= 0 deixa a tela fixa (fim de jogo).
func show_overlay(title: String, subtitle: String, seconds: float) -> void:
	_bar.overlay_title = title
	_bar.overlay_sub = subtitle
	_overlay_time = seconds
	_bar.queue_redraw()


func _ball_text(rules: GameRules) -> String:
	var spot := rules.ball_on if rules.ball_on <= 50.0 else 100.0 - rules.ball_on
	var teams: Array[String] = ["A", "B"]
	var side: String = teams[rules.possession] if rules.ball_on <= 50.0 else teams[1 - rules.possession]
	return "%s %d" % [side, int(round(spot))]


class _Bar extends Control:
	var data := {}
	var overlay_title := ""
	var overlay_sub := ""

	func _ready() -> void:
		size = Vector2(512, 448)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		if not data.is_empty():
			_draw_bar(font)
		if overlay_title != "":
			draw_rect(Rect2(0, 0, 512, 448), Color(0, 0, 0, 0.55))
			draw_string(font, Vector2(0, 210), overlay_title, HORIZONTAL_ALIGNMENT_CENTER, 512, 28, Scoreboard.ACCENT_COLOR)
			draw_string(font, Vector2(0, 240), overlay_sub, HORIZONTAL_ALIGNMENT_CENTER, 512, 16, Scoreboard.TEXT_COLOR)

	func _draw_bar(font: Font) -> void:
		draw_rect(Rect2(0, 0, 512, Scoreboard.BAR_HEIGHT), Color(0.02, 0.03, 0.08, 0.85))
		draw_rect(Rect2(0, Scoreboard.BAR_HEIGHT, 512, 1), Color(0.85, 0.85, 0.95, 0.8))
		var names := ["A", "B"]
		for i in 2:
			var x := i * 92.0
			draw_rect(Rect2(x, 0, 90, 22), Scoreboard.TEAM_COLORS[i])
			draw_string(font, Vector2(x + 6, 16), "%s  %d" % [names[i], data["score"][i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Scoreboard.TEXT_COLOR)
			for t in data["timeouts"][i]:  # um traço por timeout restante
				draw_rect(Rect2(x + 6 + t * 12, 25, 9, 3), Scoreboard.TEXT_COLOR)
			if data["possession"] == i:
				draw_colored_polygon(PackedVector2Array([Vector2(x + 72, 6), Vector2(x + 84, 11), Vector2(x + 72, 16)]), Scoreboard.ACCENT_COLOR)
		draw_string(font, Vector2(198, 16), "%s  %s" % [data["quarter"], data["clock"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Scoreboard.TEXT_COLOR)
		draw_string(font, Vector2(310, 16), data["situation"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Scoreboard.ACCENT_COLOR)
		draw_string(font, Vector2(430, 16), "BALL %s" % data["ball"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Scoreboard.TEXT_COLOR)
