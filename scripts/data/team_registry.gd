class_name TeamRegistry
extends RefCounted
## Carrega e valida os dados de jogadores (data/players) e times (data/teams), indexados por id.

const PLAYERS_DIR := "res://data/players"
const TEAMS_DIR := "res://data/teams"

var players := {}
var teams := {}
var errors: Array[String] = []


## Carrega tudo; devolve false (e preenche `errors`) se algo estiver inválido.
func load_all() -> bool:
	players.clear()
	teams.clear()
	errors.clear()
	for path in _resource_paths(PLAYERS_DIR):
		var player := load(path) as PlayerData
		if player == null:
			errors.append("%s não é um PlayerData" % path)
		else:
			_add_player(player)
	for path in _resource_paths(TEAMS_DIR):
		var team := load(path) as TeamData
		if team == null:
			errors.append("%s não é um TeamData" % path)
		else:
			_add_team(team)
	errors.append_array(check_cross(teams.values(), players))
	return errors.is_empty()


## Checagens entre times: jogador de elenco precisa estar cadastrado e não pode estar em dois elencos.
static func check_cross(team_list: Array, registered_players: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var owner_of := {}
	for team: TeamData in team_list:
		for e in team.entries:
			if e == null or e.player == null:
				continue
			var pid := e.player.id
			if not registered_players.has(pid):
				result.append("time '%s': jogador '%s' não está em %s" % [team.id, pid, PLAYERS_DIR])
			if owner_of.has(pid):
				result.append("jogador '%s' está nos elencos '%s' e '%s'" % [pid, owner_of[pid], team.id])
			owner_of[pid] = team.id
	return result


func _add_player(player: PlayerData) -> void:
	errors.append_array(player.validate())
	if players.has(player.id):
		errors.append("id de jogador repetido: '%s'" % player.id)
	players[player.id] = player


func _add_team(team: TeamData) -> void:
	errors.append_array(team.validate())
	if teams.has(team.id):
		errors.append("id de time repetido: '%s'" % team.id)
	teams[team.id] = team


## Caminhos dos .tres de uma pasta (em exportações o Godot lista "arquivo.tres.remap").
static func _resource_paths(dir: String) -> Array[String]:
	var paths: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		file = file.trim_suffix(".remap")
		if file.ends_with(".tres"):
			paths.append("%s/%s" % [dir, file])
	paths.sort()
	return paths
