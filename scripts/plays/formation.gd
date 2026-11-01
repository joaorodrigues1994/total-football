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


## Chutes. Mesmo referencial: x positivo = em direção ao time que recebe a bola.
## O primeiro da lista do time que chuta é o chutador ("K"); o do time que recebe é o retornador ("R").

const KICKOFF_KICKING := [
	{"role": "K", "pos": Vector2(-4, 0)},
	{"role": "C1", "pos": Vector2(0, -15)},
	{"role": "C2", "pos": Vector2(0, -12)},
	{"role": "C3", "pos": Vector2(0, -9)},
	{"role": "C4", "pos": Vector2(0, -6)},
	{"role": "C5", "pos": Vector2(0, -3)},
	{"role": "C6", "pos": Vector2(0, 3)},
	{"role": "C7", "pos": Vector2(0, 6)},
	{"role": "C8", "pos": Vector2(0, 9)},
	{"role": "C9", "pos": Vector2(0, 12)},
	{"role": "C10", "pos": Vector2(0, 15)},
]

const KICKOFF_RECEIVING := [
	{"role": "R", "pos": Vector2(58, 0)},
	{"role": "B1", "pos": Vector2(30, -12)},
	{"role": "B2", "pos": Vector2(30, -6)},
	{"role": "B3", "pos": Vector2(30, 0)},
	{"role": "B4", "pos": Vector2(30, 6)},
	{"role": "B5", "pos": Vector2(30, 12)},
	{"role": "B6", "pos": Vector2(42, -9)},
	{"role": "B7", "pos": Vector2(42, 0)},
	{"role": "B8", "pos": Vector2(42, 9)},
	{"role": "B9", "pos": Vector2(52, -6)},
	{"role": "B10", "pos": Vector2(52, 6)},
]

const PUNT_KICKING := [
	{"role": "K", "pos": Vector2(-14, 0)},
	{"role": "C1", "pos": Vector2(-4, 0)},
	{"role": "C2", "pos": Vector2(-1, -6)},
	{"role": "C3", "pos": Vector2(-1, -4)},
	{"role": "C4", "pos": Vector2(-1, -2)},
	{"role": "C5", "pos": Vector2(-1, 0)},
	{"role": "C6", "pos": Vector2(-1, 2)},
	{"role": "C7", "pos": Vector2(-1, 4)},
	{"role": "C8", "pos": Vector2(-1, 6)},
	{"role": "C9", "pos": Vector2(-1, -14)},
	{"role": "C10", "pos": Vector2(-1, 14)},
]

const PUNT_RECEIVING := [
	{"role": "R", "pos": Vector2(42, 0)},
	{"role": "B1", "pos": Vector2(1, -3)},
	{"role": "B2", "pos": Vector2(1, -1)},
	{"role": "B3", "pos": Vector2(1, 1)},
	{"role": "B4", "pos": Vector2(1, 3)},
	{"role": "B5", "pos": Vector2(8, -9)},
	{"role": "B6", "pos": Vector2(8, -3)},
	{"role": "B7", "pos": Vector2(8, 3)},
	{"role": "B8", "pos": Vector2(8, 9)},
	{"role": "B9", "pos": Vector2(10, -14)},
	{"role": "B10", "pos": Vector2(10, 14)},
]

const FIELD_GOAL_KICKING := [
	{"role": "K", "pos": Vector2(-8, 1.5)},
	{"role": "C1", "pos": Vector2(-7, 0)},
	{"role": "C2", "pos": Vector2(-1, -6)},
	{"role": "C3", "pos": Vector2(-1, -4)},
	{"role": "C4", "pos": Vector2(-1, -2)},
	{"role": "C5", "pos": Vector2(-1, 0)},
	{"role": "C6", "pos": Vector2(-1, 2)},
	{"role": "C7", "pos": Vector2(-1, 4)},
	{"role": "C8", "pos": Vector2(-1, 6)},
	{"role": "C9", "pos": Vector2(-1, -8)},
	{"role": "C10", "pos": Vector2(-1, 8)},
]

const FIELD_GOAL_DEFENSE := [
	{"role": "B0", "pos": Vector2(1.5, -6)},
	{"role": "B1", "pos": Vector2(1.5, -4)},
	{"role": "B2", "pos": Vector2(1.5, -2)},
	{"role": "B3", "pos": Vector2(1.5, 0)},
	{"role": "B4", "pos": Vector2(1.5, 2)},
	{"role": "B5", "pos": Vector2(1.5, 4)},
	{"role": "B6", "pos": Vector2(1.5, 6)},
	{"role": "B7", "pos": Vector2(1.5, -9)},
	{"role": "B8", "pos": Vector2(1.5, 9)},
	{"role": "B9", "pos": Vector2(6, -4)},
	{"role": "B10", "pos": Vector2(6, 4)},
]
