extends SceneTree
## Testes da Etapa 4: uniformes recoloridos, nomes e cores dos times na apresentação.
## Uso: Godot --headless --path . -s tests/appearance_suite.gd [-- caminho_da_folha_de_contato.png]

var _fails := 0
var _checks := 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("FALHA: ", what)


func _init() -> void:
	var s = load("res://scenes/main.tscn").instantiate()
	root.add_child(s)
	var m: Match = s.get_node("Match")
	await physics_frame
	_style()
	_exact_originals(m)
	_other_colors()
	_presentation(m)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_contact_sheet(args[0])
	print("RES appearance_suite: ", _checks, " verificações, ", _fails, " falhas")
	quit(1 if _fails > 0 else 0)


func _sheet(path: String) -> Image:
	return (load(path) as Texture2D).get_image()


func _same(a: Image, b: Image) -> bool:
	return a.get_size() == b.get_size() and a.get_data() == b.get_data()


func _style() -> void:
	_check(TeamStyle.light(TeamSprites.BASE_PRIMARY).to_html(false) == "6594d2", "tom claro igual ao da arte original")
	_check(TeamStyle.dark(TeamSprites.BASE_PRIMARY).to_html(false) == "002664", "tom escuro igual ao da arte original")
	_check(TeamStyle.light(Color8(200, 200, 250)).to_html(false) == "ffffff", "tom claro limitado a 255")
	_check(TeamStyle.dark(Color8(10, 20, 30)).to_html(false) == "000000", "tom escuro limitado a 0")
	_check(TeamStyle.text_on(Color8(240, 200, 30)) == TeamStyle.DARK_TEXT, "texto escuro sobre amarelo")
	_check(TeamStyle.text_on(Color8(31, 78, 140)) == TeamStyle.LIGHT_TEXT, "texto claro sobre azul")
	_check(TeamStyle.text_on(Color8(140, 31, 42)) == TeamStyle.LIGHT_TEXT, "texto claro sobre vermelho")


## Com as cores dos times genéricos a textura gerada é idêntica, pixel a pixel, aos PNG originais.
func _exact_originals(m: Match) -> void:
	var base := _sheet(TeamSprites.BASE_SHEET)
	var a := m.roster.teams[0]
	var b := m.roster.teams[1]
	_check(_same(TeamSprites.recolor(base, a.primary_color, a.secondary_color), _sheet("res://assets/sprites/player_team_a.png")),
			"time A idêntico a player_team_a.png")
	_check(_same(TeamSprites.recolor(base, b.primary_color, b.secondary_color), _sheet("res://assets/sprites/player_team_b.png")),
			"time B idêntico a player_team_b.png")
	_check(TeamSprites.sheet_for(a.primary_color, a.secondary_color) == TeamSprites.sheet_for(a.primary_color, a.secondary_color),
			"textura do time em cache")


## Outras cores: só os tons do time e o branco mudam; o resto e a transparência ficam como estavam.
func _other_colors() -> void:
	var base := _sheet(TeamSprites.BASE_SHEET)
	var swaps := {
		TeamSprites.BASE_PRIMARY.to_html(false): "p", TeamStyle.light(TeamSprites.BASE_PRIMARY).to_html(false): "l",
		TeamStyle.dark(TeamSprites.BASE_PRIMARY).to_html(false): "d", TeamSprites.BASE_SECONDARY.to_html(false): "s",
	}
	for pair in [[Color8(240, 200, 30), Color8(20, 20, 24)], [Color8(30, 140, 60), Color8(255, 255, 255)],
			[Color8(20, 20, 24), Color8(240, 120, 20)], [Color8(250, 250, 250), Color8(200, 30, 30)]]:
		var primary: Color = pair[0]
		var secondary: Color = pair[1]
		var out := TeamSprites.recolor(base, primary, secondary)
		var expected := {"p": primary, "l": TeamStyle.light(primary), "d": TeamStyle.dark(primary), "s": secondary}
		var bad := 0
		var swapped := 0
		for y in base.get_height():
			for x in base.get_width():
				var src := base.get_pixel(x, y)
				var dst := out.get_pixel(x, y)
				if src.a != dst.a:
					bad += 1
				elif src.a == 0.0:
					continue
				elif swaps.has(src.to_html(false)):
					swapped += 1
					var want: Color = expected[swaps[src.to_html(false)]]
					if dst.to_html(false) != want.to_html(false):
						bad += 1
				elif src != dst:
					bad += 1
		_check(bad == 0, "recolor %s/%s: %d pixels fora do esperado" % [primary.to_html(false), secondary.to_html(false), bad])
		_check(swapped == 3234 + 429 + 141 + 749, "recolor troca exatamente os pixels do time e o branco (%d)" % swapped)


func _presentation(m: Match) -> void:
	var a := m.roster.teams[0]
	var b := m.roster.teams[1]
	_check(m._hud.team_names == ["TMA", "TMB"], "placar com as abreviações")
	_check(m._hud.team_colors[0] == a.primary_color and m._hud.team_colors[1] == b.primary_color, "placar com as cores primárias")
	for i in 2:  # as constantes antigas eram floats arredondados: diferença de no máximo 1/255
		var c: Color = m._hud.team_colors[i]
		var old_c: Color = Scoreboard.TEAM_COLORS[i]
		_check(absf(c.r - old_c.r) < 0.01 and absf(c.g - old_c.g) < 0.01 and absf(c.b - old_c.b) < 0.01, "cor do placar do lado %d praticamente igual à antiga" % i)
	var field := m.get_parent().get_node("Field")
	_check(field.endzone_left == a.primary_color and field.endzone_right == b.primary_color, "endzones com as cores dos times")
	_check(field.endzone_left == Field.ENDZONE_LEFT and field.endzone_right == Field.ENDZONE_RIGHT, "endzones iguais às antigas")
	m.rules.start_drive(0, 40.0)
	_check(m._hud.score_line(m.rules) == "TMA 0  x  TMB 0", "linha de placar com abreviações")
	_check(m._hud._ball_text(m.rules) == "TMA 40", "BALL com a abreviação do time com a bola")
	m.rules.start_drive(1, 40.0)
	_check(m._hud._ball_text(m.rules) == "TMB 40", "BALL do time B")
	m.rules.start_drive(0, 70.0)
	_check(m._hud._ball_text(m.rules) == "TMB 30", "BALL no campo adversário usa o outro time")

	m._setup()
	for p in m.offense + m.defense:
		var club: TeamData = m.roster.teams[p.team]
		_check(p.uniform_sheet == TeamSprites.sheet_for(club.primary_color, club.secondary_color), "%s com o uniforme do time" % p.role)
		_check(p.marker_color == TeamStyle.marker_color(club.primary_color), "%s com a cor de marcador do time" % p.role)
		break

	# times invertidos: nomes, cores e uniformes acompanham o time
	var original := m.roster
	m.roster = MatchRoster.new(b, a)
	m._apply_team_style()
	_check(m._hud.team_names == ["TMB", "TMA"], "placar com times invertidos")
	_check(field.endzone_left == b.primary_color, "endzone esquerda do time B quando ele ocupa o lado A")
	m.rules.start_drive(0, 40.0)
	m._setup()
	var qb: Player = m._find(m.offense, "QB")
	_check(qb.uniform_sheet == TeamSprites.sheet_for(b.primary_color, b.secondary_color), "uniforme do time B no lado A")
	m.roster = original
	m._apply_team_style()


## Folha de contato: quadros de várias animações com cores de teste, para conferir a olho.
func _contact_sheet(path: String) -> void:
	var base := _sheet(TeamSprites.BASE_SHEET)
	var colors := [
		[Color8(31, 78, 140), Color8(236, 236, 240)], [Color8(140, 31, 42), Color8(236, 236, 240)],
		[Color8(240, 200, 30), Color8(20, 20, 24)], [Color8(30, 140, 60), Color8(255, 255, 255)],
		[Color8(20, 20, 24), Color8(240, 120, 20)], [Color8(250, 250, 250), Color8(200, 30, 30)],
		[Color8(120, 40, 160), Color8(240, 200, 30)], [Color8(240, 120, 20), Color8(20, 40, 100)],
	]
	var frame := PlayerSprites.FRAME
	var rows := [0, 1, 2, 3, 4, 5, 6, 9, 12]
	var sheet := Image.create(frame * 4 * colors.size() / 2, frame * rows.size() * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.23, 0.56, 0.24))
	for i in colors.size():
		var img := TeamSprites.recolor(base, colors[i][0], colors[i][1])
		var ox := (i % 4) * frame * 4 if false else (i % (colors.size() / 2)) * frame * 4
		var oy := (i / (colors.size() / 2)) * frame * rows.size()
		for r in rows.size():
			for f in 4:
				sheet.blend_rect(img, Rect2i(f * frame, rows[r] * frame, frame, frame), Vector2i(ox + f * frame, oy + r * frame))
	sheet.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
	print("folha de contato: ", path, " -> ", error_string(sheet.save_png(path)))
