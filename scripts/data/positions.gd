class_name Positions
extends RefCounted
## Posições dos jogadores e vagas (papéis) das formações. A posição é do jogador; a vaga é o lugar na formação
## ("WR1", "LT"...). Esta tabela diz que posições podem ocupar cada vaga. Só dados: não altera nenhuma formação.

const ALL := ["QB", "RB", "WR", "TE", "OT", "OG", "C", "DE", "DT", "LB", "CB", "S", "K"]

const SLOT_POSITIONS := {
	"LT": ["OT"], "LG": ["OG"], "C": ["C"], "RG": ["OG"], "RT": ["OT"], "TE": ["TE"],
	"QB": ["QB"], "RB": ["RB"], "WR1": ["WR"], "WR2": ["WR"], "WR3": ["WR"],
	"LDE": ["DE"], "LDT": ["DT"], "RDT": ["DT"], "RDE": ["DE"],
	"LOLB": ["LB"], "MLB": ["LB"], "ROLB": ["LB"],
	"LCB": ["CB"], "RCB": ["CB"], "FS": ["S"], "SS": ["S"],
	"K": ["K"], "R": ["WR", "RB", "CB", "S"],
}


## Vagas que todo time precisa ter com um titular: as 22 do ataque/defesa mais chutador e retornador.
## C1..C10 e B1..B10 são papéis situacionais e ficam fora do elenco (continuam em PlayerAttributes.for_role).
static func required_slots() -> Array[String]:
	var slots: Array[String] = []
	for formation in [Formation.OFFENSE, Formation.DEFENSE]:
		for slot in formation:
			slots.append(slot["role"])
	slots.append("K")
	slots.append("R")
	return slots


## O jogador pode ocupar a vaga com a posição principal ou com uma secundária.
static func fits(player: PlayerData, slot: String) -> bool:
	if not SLOT_POSITIONS.has(slot):
		return false
	var allowed: Array = SLOT_POSITIONS[slot]
	return player.position in allowed or player.secondary_positions.any(func(p): return p in allowed)
