class_name DebugHud
extends CanvasLayer
## HUD provisório em texto (placar, quarto, tempo, down e distância). O visual final vem na etapa de interface.

var _label := Label.new()
var _banner := Label.new()


func _ready() -> void:
	for l in [_label, _banner]:
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 4)
	_label.position = Vector2(6, 4)
	_label.add_theme_font_size_override("font_size", 12)
	_banner.position = Vector2(0, 40)
	_banner.size = Vector2(512, 28)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 20)
	_banner.add_theme_color_override("font_color", Color("f2d230"))
	add_child(_label)
	add_child(_banner)


func show_rules(rules: GameRules, banner: String) -> void:
	var teams: Array[String] = ["A", "B"]
	var side: String = teams[rules.possession]
	var spot := rules.ball_on if rules.ball_on <= 50.0 else 100.0 - rules.ball_on
	var spot_team: String = side if rules.ball_on <= 50.0 else teams[1 - rules.possession]
	var quarter := "FINAL" if rules.game_over else "Q%d" % rules.quarter
	_label.text = "A %d  x  B %d   %s %s   %s   Bola: %s %d  (posse %s)" % [
		rules.score[0], rules.score[1], quarter, rules.clock_text(),
		rules.down_and_distance(), spot_team, int(round(spot)), side]
	_banner.text = banner
