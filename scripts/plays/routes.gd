class_name Routes
extends RefCounted
## Rotas de recebedores. Pontos em jardas, relativos à posição inicial do jogador,
## para um time atacando para a direita (x positivo = para a frente).

const PASS_TEST := {
	"WR1": [Vector2(4, 3), Vector2(45, 3)],
	"WR2": [Vector2(4, -3), Vector2(45, -3)],
	"WR3": [Vector2(3, 0), Vector2(10, 6), Vector2(40, 6)],
	"TE": [Vector2(5, 0), Vector2(8, 5), Vector2(14, 5)],
	"RB": [Vector2(1, 5), Vector2(6, 9), Vector2(10, 9)],
}

## Ordem de seleção do alvo com a tecla S.
const TARGET_ORDER := ["WR1", "WR2", "WR3", "TE", "RB"]
