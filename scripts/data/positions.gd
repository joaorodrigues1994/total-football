class_name Positions
extends RefCounted
## Posições dos jogadores e vagas (papéis) das formações. A posição é do jogador; a vaga é o lugar na formação
## ("WR1", "LT"...). Esta tabela diz que posições podem ocupar cada vaga. Só dados: não altera nenhuma formação.

## ST = especialista de special teams (vagas C1..C10, B0..B10 das formações de chute).
const ALL := ["QB", "RB", "WR", "TE", "OT", "OG", "C", "DE", "DT", "LB", "CB", "S", "K", "ST"]

## Vagas de special teams: cobertura/chute (C#) e retorno/bloqueio (B#; B0 só existe na defesa de field goal).
const SPECIAL_SLOTS := ["C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8", "C9", "C10", "B0", "B1", "B2", "B3", "B4", "B5", "B6", "B7", "B8", "B9", "B10"]

const SLOT_POSITIONS := {
	"LT": ["OT"], "LG": ["OG"], "C": ["C"], "RG": ["OG"], "RT": ["OT"], "TE": ["TE"],
	"QB": ["QB"], "RB": ["RB"], "WR1": ["WR"], "WR2": ["WR"], "WR3": ["WR"],
	"LDE": ["DE"], "LDT": ["DT"], "RDT": ["DT"], "RDE": ["DE"],
	"LOLB": ["LB"], "MLB": ["LB"], "ROLB": ["LB"],
	"LCB": ["CB"], "RCB": ["CB"], "FS": ["S"], "SS": ["S"],
	"K": ["K"], "R": ["WR", "RB", "CB", "S"],
	"C1": ["ST"], "C2": ["ST"], "C3": ["ST"], "C4": ["ST"], "C5": ["ST"], "C6": ["ST"], "C7": ["ST"], "C8": ["ST"],
	"C9": ["ST"], "C10": ["ST"], "B0": ["ST"], "B1": ["ST"], "B2": ["ST"], "B3": ["ST"], "B4": ["ST"], "B5": ["ST"],
	"B6": ["ST"], "B7": ["ST"], "B8": ["ST"], "B9": ["ST"], "B10": ["ST"],
}


## Vagas que todo time precisa ter com um titular: as 22 do ataque/defesa, chutador, retornador e as 21 de special teams.
static func required_slots() -> Array[String]:
	var slots: Array[String] = []
	for formation in [Formation.OFFENSE, Formation.DEFENSE]:
		for slot in formation:
			slots.append(slot["role"])
	slots.append("K")
	slots.append("R")
	slots.append_array(SPECIAL_SLOTS)
	return slots


## O jogador pode ocupar a vaga com a posição principal ou com uma secundária.
static func fits(player: PlayerData, slot: String) -> bool:
	if not SLOT_POSITIONS.has(slot):
		return false
	var allowed: Array = SLOT_POSITIONS[slot]
	return player.position in allowed or player.secondary_positions.any(func(p): return p in allowed)
