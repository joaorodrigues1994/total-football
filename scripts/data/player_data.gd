class_name PlayerData
extends Resource
## Jogador como indivíduo: identidade permanente e atributos-base. Não guarda time nem número de camisa
## (isso é do vínculo, ver RosterEntry) nem condição de partida (ver PlayerMatchState).

@export var id := ""
@export var display_name := ""
@export var position := ""
@export var secondary_positions: Array[String] = []
@export var attributes: PlayerAttributes


## Mensagens de erro dos dados obrigatórios; vazio = válido.
func validate() -> Array[String]:
	var errors: Array[String] = []
	var who := "jogador '%s'" % id
	if id.is_empty():
		errors.append("jogador sem id (%s)" % resource_path)
	if display_name.is_empty():
		errors.append("%s sem nome" % who)
	if not position in Positions.ALL:
		errors.append("%s com posição inválida '%s'" % [who, position])
	for p in secondary_positions:
		if not p in Positions.ALL:
			errors.append("%s com posição secundária inválida '%s'" % [who, p])
	if attributes == null:
		errors.append("%s sem atributos" % who)
	else:
		for attr in PlayerMatchState.ATTRIBUTES:
			var value: int = attributes.get(attr)
			if value < 1 or value > 100:
				errors.append("%s com %s fora de 1..100 (%d)" % [who, attr, value])
	return errors
