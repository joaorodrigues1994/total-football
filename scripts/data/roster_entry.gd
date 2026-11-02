class_name RosterEntry
extends Resource
## Vínculo de um jogador com uma equipe. Dados que só fazem sentido dentro do elenco ficam aqui (número,
## vaga de titular); contrato e data de entrada entrarão aqui no futuro, sem tocar no PlayerData.

@export var player: PlayerData
@export var jersey_number := 0
## Vaga que ocupa como titular (ex.: "LT", "WR2", "K"); vazio = reserva.
@export var starter_slot := ""


func is_starter() -> bool:
	return not starter_slot.is_empty()
