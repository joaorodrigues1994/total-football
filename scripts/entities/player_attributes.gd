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
## Hitting Power: força do golpe em bloqueios e confrontos (principal na disputa de bloqueio).
@export_range(1, 100) var hitting_power := 50

## Hitting Power base por posição (ver BlockSystem).
const BASE_HITTING_POWER := {
	"LT": 72, "LG": 72, "C": 72, "RG": 72, "RT": 72, "TE": 60, "QB": 30, "RB": 50,
	"WR1": 40, "WR2": 40, "WR3": 40,
	"LDE": 65, "RDE": 65, "LDT": 68, "RDT": 68, "LOLB": 60, "MLB": 60, "ROLB": 60,
	"LCB": 40, "RCB": 40, "FS": 40, "SS": 40, "K": 35, "R": 45,
}
const COVER_HITTING_POWER := 50
const BLOCKER_HITTING_POWER := 60


## Velocidade máxima em jardas/segundo.
func max_speed_yards() -> float:
	return remap(speed, 1.0, 100.0, 5.0, 10.0)


## Aceleração em jardas/segundo².
func acceleration_yards() -> float:
	return remap(acceleration, 1.0, 100.0, 15.0, 45.0)


## Atributos iniciais de uma posição (por enquanto só muda o Hitting Power).
static func for_role(role: String) -> PlayerAttributes:
	var attrs := PlayerAttributes.new()
	if BASE_HITTING_POWER.has(role):
		attrs.hitting_power = BASE_HITTING_POWER[role]
	elif role.begins_with("C"):
		attrs.hitting_power = COVER_HITTING_POWER
	elif role.begins_with("B"):
		attrs.hitting_power = BLOCKER_HITTING_POWER
	return attrs
