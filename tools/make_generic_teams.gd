extends SceneTree
## Gera os .tres dos dois times genéricos (equivalentes aos times A e B antigos) em data/players e data/teams.
## Uso: Godot --headless --path . -s tools/make_generic_teams.gd
## Atributos gerais 50 e hitting_power pela tabela de PlayerAttributes.BASE_HITTING_POWER (via for_role).

const GENERIC := [
	{"id": "gen_a", "name": "Time A", "abbr": "TMA", "primary": Color8(31, 78, 140), "secondary": Color8(236, 236, 240)},
	{"id": "gen_b", "name": "Time B", "abbr": "TMB", "primary": Color8(140, 31, 42), "secondary": Color8(236, 236, 240)},
]
## Reservas de teste: [chave, posição, vaga cujo perfil de atributos usam].
const RESERVES := [["res_qb", "QB", "QB"], ["res_wr", "WR", "WR1"]]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TeamRegistry.PLAYERS_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TeamRegistry.TEAMS_DIR))
	for g in GENERIC:
		var team := TeamData.new()
		team.id = g["id"]
		team.full_name = g["name"]
		team.abbreviation = g["abbr"]
		team.primary_color = g["primary"]
		team.secondary_color = g["secondary"]
		var number := 1
		for slot in Positions.required_slots():
			team.entries.append(_entry(g, slot.to_lower(), _position_for(slot), slot, slot, number))
			number += 1
		for r in RESERVES:
			team.entries.append(_entry(g, r[0], r[1], "", r[2], number))
			number += 1
		var path := "%s/%s.tres" % [TeamRegistry.TEAMS_DIR, team.id]
		print(path, " -> ", error_string(ResourceSaver.save(team, path)))
	quit()


func _position_for(slot: String) -> String:
	return "WR" if slot == "R" else Positions.SLOT_POSITIONS[slot][0]


func _entry(g: Dictionary, key: String, position: String, slot: String, profile_role: String, number: int) -> RosterEntry:
	var player := PlayerData.new()
	player.id = "%s_%s" % [g["id"], key]
	player.display_name = "Jogador %s-%s" % [g["abbr"].right(1), key.to_upper()]
	player.position = position
	player.attributes = PlayerAttributes.for_role(profile_role)
	var path := "%s/%s.tres" % [TeamRegistry.PLAYERS_DIR, player.id]
	ResourceSaver.save(player, path)
	player.take_over_path(path)
	var entry := RosterEntry.new()
	entry.player = player
	entry.jersey_number = number
	entry.starter_slot = slot
	return entry
