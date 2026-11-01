class_name GameRules
extends RefCounted
## Regras da partida, independentes da apresentação: posse, downs, jardas, placar e relógio (NFL).
##
## Posições em jardas a partir da goal line do PRÓPRIO time que está com a bola (1 a 99).
## Times: 0 = Time A, 1 = Time B.

const QUARTER_SECONDS := 120.0
const QUARTERS := 4
const TOUCHDOWN_POINTS := 6
## Posição inicial de cada posse. TEMPORÁRIO: some quando existir o kickoff.
const START_YARD := 25.0

var score: Array[int] = [0, 0]
var quarter := 1
var clock := QUARTER_SECONDS
## O relógio só corre com a jogada em andamento ou depois de um tackle dentro do campo.
var clock_running := false
var play_active := false
var game_over := false

var possession := 0
var ball_on := START_YARD
var down := 1
var line_to_gain := START_YARD + 10.0
var opening_possession := 0


func _init() -> void:
	start_drive(opening_possession, START_YARD)


func start_drive(team: int, yard: float) -> void:
	possession = team
	ball_on = yard
	down = 1
	line_to_gain = minf(yard + 10.0, 100.0)


## O ataque dá o snap: a jogada começa e o relógio corre.
func snap() -> void:
	if game_over:
		return
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


## Encerra a jogada. outcome: "touchdown", "incomplete" ou uma jogada que termina com o portador
## no chão ("tackle", "sack", "down"); new_spot é onde a bola ficou (jardas da própria goal line).
func end_play(outcome: String, new_spot: float) -> Dictionary:
	var events := {
		"first_down": false, "turnover": false, "touchdown": false,
		"quarter_ended": false, "game_over": false,
	}
	play_active = false
	match outcome:
		"touchdown":
			score[possession] += TOUCHDOWN_POINTS
			clock_running = false
			events["touchdown"] = true
			_change_possession(START_YARD)
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
	if clock <= 0.0:
		_end_quarter()
		events["quarter_ended"] = true
		events["game_over"] = game_over
	return events


## TEMPORÁRIO (tecla T): passa a bola ao outro time no mesmo ponto do campo.
func flip_possession_same_spot() -> void:
	start_drive(1 - possession, 100.0 - ball_on)


func yards_to_go() -> int:
	return ceili(line_to_gain - ball_on)


func down_and_distance() -> String:
	var ordinals := ["1st", "2nd", "3rd", "4th"]
	var dist := "Goal" if line_to_gain >= 100.0 else str(yards_to_go())
	return "%s & %s" % [ordinals[clampi(down - 1, 0, 3)], dist]


func clock_text() -> String:
	var secs := ceili(clock)
	return "%d:%02d" % [secs / 60, secs % 60]


func _next_down(events: Dictionary) -> void:
	down += 1
	if down > 4:
		events["turnover"] = true
		clock_running = false
		_change_possession(100.0 - ball_on)  # turnover on downs


func _change_possession(yard_from_own_goal: float) -> void:
	start_drive(1 - possession, yard_from_own_goal)


func _end_quarter() -> void:
	clock_running = false
	if quarter >= QUARTERS:
		game_over = true
		return
	quarter += 1
	clock = QUARTER_SECONDS
	if quarter == 3:  # segundo tempo: recebe o time que não começou com a bola
		start_drive(1 - opening_possession, START_YARD)
