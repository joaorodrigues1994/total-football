class_name PlayerMatchState
extends RefCounted
## Condição temporária de um jogador numa partida. Os atributos-base ficam em PlayerData e nunca são alterados
## aqui: o desempenho efetivo é base + modificadores, com limite de 1 a 100. Sem modificadores (estado atual do
## jogo) os atributos efetivos são idênticos aos base.

const ATTRIBUTES := ["speed", "acceleration", "strength", "agility", "receiving", "pass_accuracy", "hitting_power"]
const MIN_VALUE := 1
const MAX_VALUE := 100

var data: PlayerData
## Atributo (nome acima) -> variação temporária somada ao valor-base.
var modifiers := {}


func _init(player_data: PlayerData) -> void:
	data = player_data


func effective(attribute: String) -> int:
	return clampi(int(data.attributes.get(attribute)) + int(modifiers.get(attribute, 0)), MIN_VALUE, MAX_VALUE)


## Cópia dos atributos já com os modificadores; é o que o jogador em campo consulta.
func effective_attributes() -> PlayerAttributes:
	var result := PlayerAttributes.new()
	for attr in ATTRIBUTES:
		result.set(attr, effective(attr))
	return result
