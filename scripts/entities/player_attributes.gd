class_name PlayerAttributes
extends Resource
## Atributos do jogador. Só os essenciais da Fase 1; novos atributos entram como novos @export.
## Valores de 1 a 100 (50 = médio), convertidos para unidades de jogo pelos métodos abaixo.

@export_range(1, 100) var speed := 50
@export_range(1, 100) var acceleration := 50
@export_range(1, 100) var strength := 50
@export_range(1, 100) var agility := 50
@export_range(1, 100) var receiving := 50
@export_range(1, 100) var pass_accuracy := 50


## Velocidade máxima em jardas/segundo.
func max_speed_yards() -> float:
	return remap(speed, 1.0, 100.0, 5.0, 10.0)


## Aceleração em jardas/segundo².
func acceleration_yards() -> float:
	return remap(acceleration, 1.0, 100.0, 15.0, 45.0)
