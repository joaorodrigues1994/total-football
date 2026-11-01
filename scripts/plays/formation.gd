class_name Formation
extends RefCounted
## Formações iniciais. "pos" em jardas relativas à bola, para um time atacando para a direita:
## x negativo = atrás da linha de scrimmage (ataque); y negativo = lado esquerdo do ataque.
## A ordem da lista é a ordem de troca de jogador na defesa (esquerda -> direita, linha, LBs, defensive backs).

const OFFENSE := [
	{"role": "LT", "pos": Vector2(-1, -4)},
	{"role": "LG", "pos": Vector2(-1, -2)},
	{"role": "C", "pos": Vector2(-1, 0)},
	{"role": "RG", "pos": Vector2(-1, 2)},
	{"role": "RT", "pos": Vector2(-1, 4)},
	{"role": "TE", "pos": Vector2(-1, 6)},
	{"role": "QB", "pos": Vector2(-3, 0)},
	{"role": "RB", "pos": Vector2(-6, 0)},
	{"role": "WR1", "pos": Vector2(-1, -12)},
	{"role": "WR2", "pos": Vector2(-1, 12)},
	{"role": "WR3", "pos": Vector2(-2, -8)},
]

const DEFENSE := [
	{"role": "LDE", "pos": Vector2(1.5, -3)},
	{"role": "LDT", "pos": Vector2(1.5, -1)},
	{"role": "RDT", "pos": Vector2(1.5, 1)},
	{"role": "RDE", "pos": Vector2(1.5, 3)},
	{"role": "LOLB", "pos": Vector2(5, -5)},
	{"role": "MLB", "pos": Vector2(5, 0)},
	{"role": "ROLB", "pos": Vector2(5, 5)},
	{"role": "LCB", "pos": Vector2(6, -12)},
	{"role": "RCB", "pos": Vector2(6, 12)},
	{"role": "FS", "pos": Vector2(12, -4)},
	{"role": "SS", "pos": Vector2(12, 4)},
]
