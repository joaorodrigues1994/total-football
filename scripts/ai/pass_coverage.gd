class_name PassCoverage
extends RefCounted
## Cobertura de passe da defesa: cada defensor que não ataca o QB recebe um recebedor no snap (um defensor por
## recebedor); os que sobram dão ajuda em profundidade. O defensor mira onde o recebedor estará (agility define a
## antecipação) e, com a bola no ar, só disputa a bola quem consegue chegar a tempo; os demais mantêm a marcação.

const SWAP_INTERVAL := 0.4
const SWAP_MARGIN := 24.0
const MAN_CUSHION := 8.0
const HELP_CUSHION := 36.0
const LEAD_CLUMSY := 0.15
const LEAD_AGILE := 0.45
const REACH_SLACK := 0.35

var _man := {}   # Player (defensor) -> Player (recebedor)
var _help := {}  # Player (defensor) -> Player (recebedor mais profundo)
var _timer := 0.0
var _receivers: Array[Player] = []


## Atribui um recebedor a cada defensor, do par mais próximo ao mais distante; sobras viram ajuda em profundidade.
func begin(coverers: Array[Player], receivers: Array[Player], attack_dir: float) -> void:
	_man.clear()
	_help.clear()
	_timer = 0.0
	_receivers = receivers
	var pairs: Array = []
	for d in coverers:
		for r in receivers:
			pairs.append([d.global_position.distance_to(r.global_position), d, r])
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var taken := {}
	for pair in pairs:
		var d: Player = pair[1]
		var r: Player = pair[2]
		if _man.has(d) or taken.has(r):
			continue
		_man[d] = r
		taken[r] = true
	var deepest: Player = receivers[0]
	for r in receivers:
		if r.global_position.x * attack_dir > deepest.global_position.x * attack_dir:
			deepest = r
	for d in coverers:
		if not _man.has(d):
			_help[d] = deepest


func clear() -> void:
	_man.clear()
	_help.clear()


func covers(player: Player) -> bool:
	return _man.has(player) or _help.has(player)


## Chamado a cada frame durante o dropback e o bolso: se a troca de dois defensores encurta a marcação, eles trocam.
func tick(delta: float) -> void:
	_timer += delta
	if _timer < SWAP_INTERVAL:
		return
	_timer = 0.0
	var defenders: Array = _man.keys()
	for i in defenders.size():
		for j in range(i + 1, defenders.size()):
			var a: Player = defenders[i]
			var b: Player = defenders[j]
			var ra: Player = _man[a]
			var rb: Player = _man[b]
			var now := a.global_position.distance_to(ra.global_position) + b.global_position.distance_to(rb.global_position)
			var swapped := a.global_position.distance_to(rb.global_position) + b.global_position.distance_to(ra.global_position)
			if swapped + SWAP_MARGIN < now:
				_man[a] = rb
				_man[b] = ra
				return


## Alvo do defensor: o recebedor marcado (ou ajuda) com antecipação. Com a bola no ar (to != null), vai à bola se alcança.
func target(player: Player, attack_dir: float, to: Variant = null, time_left := 0.0, intended: Player = null) -> Variant:
	var receiver: Player = _man.get(player, _help.get(player))
	if receiver == null:
		return null
	if to != null and (receiver == intended or _can_reach(player, to, time_left)):
		return to
	var cushion := MAN_CUSHION if _man.has(player) else HELP_CUSHION
	var lead := lerpf(LEAD_CLUMSY, LEAD_AGILE, player.attributes.agility / 100.0)
	return receiver.global_position + receiver.velocity * lead + Vector2(attack_dir * cushion, 0.0)


func _can_reach(player: Player, spot: Vector2, time_left: float) -> bool:
	var speed := FieldConstants.yards_to_px(player.attributes.max_speed_yards())
	return player.global_position.distance_to(spot) / speed <= time_left + REACH_SLACK
