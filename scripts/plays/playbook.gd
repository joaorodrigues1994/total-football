class_name Playbook
extends RefCounted
## Playbook fixo do ataque e da defesa: 8 jogadas de cada, uma por combinação direção + A (terrestre /
## contra corrida) ou direção + S (aérea / contra passe). Cada jogada é só dados:
##   ataque: type ("run"/"pass"), block (esquema de BlockSchemes), mirror (espelha o esquema), routes (passes)
##   defesa: type ("run"/"pass"), rush (quem ataca o QB/portador desde o snap, nos passes),
##           hold (quem espera o portador cruzar a linha de scrimmage, nas corridas)

const DIRECTIONS := ["up", "down", "left", "right"]
const DEFENSE_LINE := ["LDE", "LDT", "RDT", "RDE"]
const LINEBACKERS := ["LOLB", "MLB", "ROLB"]
const SECONDARY := ["LCB", "RCB", "FS", "SS"]

## Rotas por posição, em jardas relativas ao ponto de partida (x = para a frente, y = lateral).
const PASS_SHORT_ROUTES := {
	"WR1": [Vector2(6, 2)],
	"WR2": [Vector2(6, -2)],
	"WR3": [Vector2(3, 2), Vector2(6, 6)],
	"TE": [Vector2(5, 0)],
	"RB": [Vector2(5, 5), Vector2(6, 9)],
}
const PASS_MEDIUM_ROUTES := {
	"WR1": [Vector2(5, 0), Vector2(12, 6)],
	"WR2": [Vector2(5, 0), Vector2(12, -6)],
	"WR3": [Vector2(8, 0), Vector2(10, -4)],
	"TE": [Vector2(8, 0), Vector2(15, 0)],
	"RB": [Vector2(1, 5), Vector2(4, 8)],
}
const PASS_DEEP_ROUTES := {
	"WR1": [Vector2(4, 0), Vector2(45, 0)],
	"WR2": [Vector2(4, 0), Vector2(45, 0)],
	"WR3": [Vector2(5, 0), Vector2(30, 5)],
	"TE": [Vector2(5, 0), Vector2(8, 0)],
	"RB": [Vector2(1, 5), Vector2(6, 9)],
}

const OFFENSE := {
	"up_a": {"name": "MIDDLE", "type": "run", "block": "run_middle", "mirror": false},
	"down_a": {"name": "SWEEP R", "type": "run", "block": "run_outside", "mirror": false},
	"left_a": {"name": "SWEEP L", "type": "run", "block": "run_outside", "mirror": true},
	"right_a": {"name": "RIGHT GAP", "type": "run", "block": "run_right_gap", "mirror": false},
	"up_s": {"name": "SHORT", "type": "pass", "block": "pass_short", "routes": PASS_SHORT_ROUTES},
	"down_s": {"name": "MEDIUM", "type": "pass", "block": "pass_short", "routes": PASS_MEDIUM_ROUTES},
	"left_s": {"name": "DEEP", "type": "pass", "block": "pass_long", "routes": PASS_DEEP_ROUTES},
	"right_s": {"name": "MIX", "type": "pass", "block": "pass_short", "routes": Routes.PASS_TEST},
}

const DEFENSE := {
	"up_a": {"name": "BASE", "type": "run", "hold": []},
	"down_a": {"name": "FULL BOX", "type": "run", "hold": SECONDARY},
	"left_a": {"name": "CONTAIN L", "type": "run", "hold": ["LDE", "LOLB", "LCB"]},
	"right_a": {"name": "CONTAIN R", "type": "run", "hold": ["RDE", "ROLB", "RCB"]},
	"up_s": {"name": "RUSH 4", "type": "pass", "rush": DEFENSE_LINE},
	"down_s": {"name": "LB BLITZ", "type": "pass", "rush": DEFENSE_LINE + LINEBACKERS},
	"left_s": {"name": "RUSH 3", "type": "pass", "rush": ["LDE", "LDT", "RDE"]},
	"right_s": {"name": "BIG BLITZ", "type": "pass", "rush": DEFENSE_LINE + LINEBACKERS + ["SS"]},
}



static func offense_play(direction: String, air: bool) -> Dictionary:
	return OFFENSE[_key(direction, air)]


static func defense_play(direction: String, air: bool) -> Dictionary:
	return DEFENSE[_key(direction, air)]


## Jogada defensiva aleatória entre as 8 cadastradas (usada quando o play clock zera sem escolha).
static func random_defense(rng: RandomNumberGenerator) -> Dictionary:
	var keys := DEFENSE.keys()
	return DEFENSE[keys[rng.randi() % keys.size()]]


static func random_offense(rng: RandomNumberGenerator) -> Dictionary:
	var keys := OFFENSE.keys()
	return OFFENSE[keys[rng.randi() % keys.size()]]


## Sorteia uma jogada de um tipo ("run" ou "pass") do playbook defensivo.
static func random_defense_of_type(rng: RandomNumberGenerator, type: String) -> Dictionary:
	var options: Array[Dictionary] = []
	for play in DEFENSE.values():
		if play["type"] == type:
			options.append(play)
	return options[rng.randi() % options.size()]


static func _key(direction: String, air: bool) -> String:
	return "%s_%s" % [direction, "s" if air else "a"]
