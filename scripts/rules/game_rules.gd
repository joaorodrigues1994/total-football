class_name GameRules
extends RefCounted
## Regras da partida, independentes da apresentação: posse, downs, jardas, placar, relógio (NFL),
## chutes (kickoff, punt, field goal, extra point) e conversão de 2 pontos.
##
## Posições em jardas a partir da goal line do PRÓPRIO time que está com a bola (1 a 99).
## Times: 0 = Time A, 1 = Time B.

enum Next { SCRIMMAGE, KICKOFF, EXTRA_POINT, TWO_POINT }

const QUARTER_SECONDS := 120.0
const QUARTERS := 4
const TOUCHDOWN_POINTS := 6
const FIELD_GOAL_POINTS := 3
const KICKOFF_YARD := 35.0
const KICKOFF_TOUCHBACK_YARD := 30.0
const PUNT_TOUCHBACK_YARD := 20.0
## Bola na jarda 15 do adversário (extra point) e na jarda 2 (conversão de 2 pontos).
const EXTRA_POINT_YARD := 85.0
const TWO_POINT_YARD := 98.0
## Jardas extras do chute: endzone (10) + posição do holder (7).
const KICK_EXTRA_YARDS := 17.0
## Chance de acerto do field goal por distância total do chute (jardas).
const FIELD_GOAL_CHANCE := [
	Vector2(20, 0.99), Vector2(30, 0.95), Vector2(40, 0.85), Vector2(50, 0.65),
	Vector2(55, 0.5), Vector2(60, 0.35), Vector2(70, 0.1), Vector2(75, 0.0),
]

var score: Array[int] = [0, 0]
var quarter := 1
var clock := QUARTER_SECONDS
## O relógio só corre com a jogada em andamento ou depois de um tackle dentro do campo.
var clock_running := false
var play_active := false
var game_over := false

var possession := 0
var ball_on := KICKOFF_YARD
var down := 1
var line_to_gain := KICKOFF_YARD + 10.0
## O que vem a seguir: jogada normal, kickoff, extra point ou conversão de 2 pontos.
var next_play := Next.KICKOFF
## Depois de um touchdown o time que marcou ainda pode trocar o extra point pelos 2 pontos.
var conversion_open := false
var opening_possession := 0
var rng := RandomNumberGenerator.new()

var _halftime_pending := false


func _init() -> void:
	start_kickoff(1 - opening_possession)


func start_drive(team: int, yard: float) -> void:
	possession = team
	ball_on = yard
	down = 1
	line_to_gain = minf(yard + 10.0, 100.0)
	next_play = Next.SCRIMMAGE


func start_kickoff(kicking_team: int) -> void:
	possession = kicking_team
	ball_on = KICKOFF_YARD
	down = 1
	next_play = Next.KICKOFF
	conversion_open = false
	clock_running = false


## O ataque dá o snap: a jogada começa e o relógio corre.
func snap() -> void:
	if game_over:
		return
	play_active = true
	clock_running = true


## Jogada sem relógio (extra point, conversão, kickoff até o retorno).
func begin_untimed_play() -> void:
	if game_over:
		return
	play_active = true


## Kickoff ou punt recebido: a posse passa a quem pegou a bola e o relógio passa a correr.
func begin_return() -> void:
	possession = 1 - possession
	play_active = true
	clock_running = true


## Avança o relógio. Retorna true se o quarto acabou entre jogadas.
func tick(delta: float) -> bool:
	if game_over or not clock_running:
		return false
	clock = maxf(clock - delta, 0.0)
	if clock > 0.0:
		return false
	clock_running = false
	if play_active:
		return false  # a jogada em andamento termina; o quarto acaba depois dela
	_end_quarter()
	return true


## Encerra uma jogada normal. outcome: "touchdown", "incomplete" ou uma jogada que termina com o portador
## no chão ("tackle", "sack", "down"); new_spot é onde a bola ficou (jardas da própria goal line).
func end_play(outcome: String, new_spot: float) -> Dictionary:
	var events := _new_events()
	play_active = false
	match outcome:
		"touchdown":
			_score_touchdown(events)
		"incomplete":
			clock_running = false
			_next_down(events)
		_:
			ball_on = clampf(new_spot, 1.0, 99.0)
			if ball_on >= line_to_gain:
				down = 1
				line_to_gain = minf(ball_on + 10.0, 100.0)
				events["first_down"] = true
			else:
				_next_down(events)
	return _finish(events)


## Fim do retorno de kickoff/punt. A posse já passou a quem recebeu.
func end_return(outcome: String, new_spot: float) -> Dictionary:
	var events := _new_events()
	play_active = false
	if outcome == "touchdown":
		_score_touchdown(events)
	else:
		start_drive(possession, clampf(new_spot, 1.0, 99.0))
	return _finish(events)


## Kickoff ou punt que termina sem retorno. touchback_yard: onde o receptor começa se a bola
## cair na endzone; senão a bola fica onde caiu (landing_spot, jardas da goal line do time que chutou).
func end_kick_without_return(landing_spot: float, touchback_yard: float) -> Dictionary:
	var events := _new_events()
	play_active = false
	clock_running = false
	var receiver := 1 - possession
	if landing_spot >= 100.0:
		events["touchback"] = true
		start_drive(receiver, touchback_yard)
	else:
		start_drive(receiver, 100.0 - landing_spot)
	return _finish(events)


func end_field_goal(good: bool) -> Dictionary:
	var events := _new_events()
	play_active = false
	clock_running = false
	events["kick_good"] = good
	if good:
		score[possession] += FIELD_GOAL_POINTS
		start_kickoff(possession)
	else:  # time adversário fica na posição do chute (7 jardas atrás da linha), no mínimo na 20
		start_drive(1 - possession, maxf(20.0, 100.0 - (ball_on - 7.0)))
	return _finish(events)


func end_extra_point(good: bool) -> Dictionary:
	var events := _new_events()
	play_active = false
	events["kick_good"] = good
	if good:
		score[possession] += 1
	_after_conversion()
	return _finish(events)


func end_two_point(good: bool) -> Dictionary:
	var events := _new_events()
	play_active = false
	events["kick_good"] = good
	if good:
		score[possession] += 2
	_after_conversion()
	return _finish(events)


## Depois do touchdown: extra point (padrão) ou conversão de 2 pontos.
func choose_conversion(two_point: bool) -> void:
	conversion_open = false
	ball_on = TWO_POINT_YARD if two_point else EXTRA_POINT_YARD
	next_play = Next.TWO_POINT if two_point else Next.EXTRA_POINT
	down = 1
	line_to_gain = 100.0


## Distância total do chute (field goal ou extra point) com a bola em ball_on.
func kick_distance() -> float:
	return (100.0 - ball_on) + KICK_EXTRA_YARDS


static func field_goal_chance(distance: float) -> float:
	var table := FIELD_GOAL_CHANCE
	if distance <= table[0].x:
		return table[0].y
	for i in range(1, table.size()):
		if distance <= table[i].x:
			var t := inverse_lerp(table[i - 1].x, table[i].x, distance)
			return lerpf(table[i - 1].y, table[i].y, t)
	return 0.0


func roll_field_goal() -> bool:
	return rng.randf() < field_goal_chance(kick_distance())


## Distância sorteada do chute, em jardas: "kickoff" ou "punt".
func roll_kick_yards(kind: String) -> float:
	return rng.randf_range(58.0, 68.0) if kind == "kickoff" else rng.randf_range(38.0, 50.0)


## TEMPORÁRIO (tecla T): passa a bola ao outro time no mesmo ponto do campo.
func flip_possession_same_spot() -> void:
	start_drive(1 - possession, 100.0 - ball_on)


func yards_to_go() -> int:
	return ceili(line_to_gain - ball_on)


func down_and_distance() -> String:
	match next_play:
		Next.KICKOFF:
			return "Kickoff"
		Next.EXTRA_POINT:
			return "Extra point"
		Next.TWO_POINT:
			return "2-pt"
	var ordinals := ["1st", "2nd", "3rd", "4th"]
	var dist := "Goal" if line_to_gain >= 100.0 else str(yards_to_go())
	return "%s & %s" % [ordinals[clampi(down - 1, 0, 3)], dist]


func clock_text() -> String:
	var secs := ceili(clock)
	return "%d:%02d" % [secs / 60, secs % 60]


func _new_events() -> Dictionary:
	return {
		"first_down": false, "turnover": false, "touchdown": false, "touchback": false,
		"kick_good": false, "quarter_ended": false, "game_over": false,
	}


func _score_touchdown(events: Dictionary) -> void:
	score[possession] += TOUCHDOWN_POINTS
	clock_running = false
	events["touchdown"] = true
	start_drive(possession, EXTRA_POINT_YARD)
	next_play = Next.EXTRA_POINT
	conversion_open = true


func _next_down(events: Dictionary) -> void:
	down += 1
	if down > 4:
		events["turnover"] = true
		clock_running = false
		start_drive(1 - possession, 100.0 - ball_on)  # turnover on downs


func _after_conversion() -> void:
	conversion_open = false
	if _halftime_pending:
		_halftime_pending = false
		start_kickoff(opening_possession)
	else:
		start_kickoff(possession)


## Confere o fim do quarto depois de qualquer jogada.
func _finish(events: Dictionary) -> Dictionary:
	if clock <= 0.0:
		_end_quarter()
		events["quarter_ended"] = true
		events["game_over"] = game_over
	return events


func _end_quarter() -> void:
	clock_running = false
	if quarter >= QUARTERS:
		game_over = true
		return
	quarter += 1
	clock = QUARTER_SECONDS
	if quarter == 3:  # segundo tempo: kickoff do time que abriu o jogo recebendo
		if next_play == Next.EXTRA_POINT or next_play == Next.TWO_POINT:
			_halftime_pending = true  # primeiro a conversão do touchdown
		else:
			start_kickoff(opening_possession)
