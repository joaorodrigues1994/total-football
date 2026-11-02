class_name MatchRoster
extends RefCounted
## Os dois elencos de uma partida (índice = lado lógico, 0 = A e 1 = B), a escalação de cada um (Lineup, que as
## substituições alteram) e o PlayerMatchState de cada jogador usado nela. O estado é criado na primeira vez que o
## jogador entra em campo e reaproveitado nas jogadas seguintes, já que os nós Player são recriados a cada jogada.

var teams: Array[TeamData] = []
var lineups: Array[Lineup] = []
var _states := {}
var _warned := {}


func _init(side_a: TeamData, side_b: TeamData) -> void:
	teams = [side_a, side_b]
	lineups = [Lineup.new(side_a), Lineup.new(side_b)]


## Estado do titular da vaga no time do lado dado; null se o time não tem titular nela (usa-se o fallback).
func state_for(side: int, slot: String) -> PlayerMatchState:
	var player := lineups[side].occupant(slot)
	if player == null:
		var key := "%d/%s" % [side, slot]
		if not _warned.has(key):
			_warned[key] = true
			push_warning("time '%s' sem titular na vaga %s: usando PlayerAttributes.for_role" % [teams[side].id, slot])
		return null
	if not _states.has(player.id):
		_states[player.id] = PlayerMatchState.new(player)
	return _states[player.id]


func state_of(player_id: String) -> PlayerMatchState:
	return _states.get(player_id)
