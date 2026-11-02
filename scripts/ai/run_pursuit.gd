class_name RunPursuit
extends RefCounted
## Perseguição do portador pela defesa: mira o ponto de interceptação (onde o portador estará quando o defensor
## chegar) em vez da posição atual, e os safeties ficam em profundidade até o portador se aproximar.
## Os demais se dividem por ordem de proximidade: o mais perto vai direto ao tackle; quem está à frente fecha o
## ângulo (mira mais adiante); quem está nas laterais mantém-se por fora (contenção); quem está atrás persegue.
## Ninguém escolhe exatamente o ponto de quem já está mais perto.
## Atributos usados (sem criar novos): speed (tempo de chegada) e agility (quanto o defensor lê a trajetória).

const MAX_LEAD := 0.7
const READ_CLUMSY := 0.6
const READ_AGILE := 1.0
const SAFETY_ROLES := ["FS", "SS"]
## Distância do portador (px) em que o safety deixa a profundidade e persegue.
const SAFETY_ENGAGE := 72.0
## Profundidade (px, para dentro da defesa) que o safety mantém à frente do portador.
const SAFETY_DEPTH := 48.0
const SAFETY_TRACK := 0.7
## Fechar o ângulo: quanto o defensor à frente do portador mira além do ponto de interceptação.
const CUTOFF_LEAD := 1.6
## Contenção: o defensor lateral mira este tanto (px) para fora do ponto de interceptação.
const CONTAIN_OUT := 14.0
const CONTAIN_LATERAL := 24.0
## Dentro desta distância (px) do portador a contenção vira tackle direto.
const CONTAIN_ENGAGE := 40.0
## Separação: aliado mais perto do portador a menos disso do ponto-alvo empurra o alvo para o lado.
const SEPARATION_RADIUS := 22.0
const SEPARATION_PUSH := 16.0


## Alvo do defensor contra o portador. attack_dir = sentido do ataque; deep_guard liga a profundidade dos safeties.
static func target(player: Player, carrier: Player, attack_dir: float, deep_guard: bool,
		teammates: Array[Player] = []) -> Vector2:
	var to_carrier := carrier.global_position - player.global_position
	if deep_guard and player.role in SAFETY_ROLES and to_carrier.length() > SAFETY_ENGAGE \
			and (player.global_position.x - carrier.global_position.x) * attack_dir > SAFETY_DEPTH * 0.5:
		var depth_x := carrier.global_position.x + attack_dir * SAFETY_DEPTH
		return Vector2(depth_x, lerpf(player.global_position.y, carrier.global_position.y, SAFETY_TRACK))
	var speed := FieldConstants.yards_to_px(player.attributes.max_speed_yards())
	var read := lerpf(READ_CLUMSY, READ_AGILE, player.attributes.agility / 100.0)
	var dist := to_carrier.length()
	var lead := minf(dist / speed, MAX_LEAD) * read
	var closer: Array[Player] = []
	for o in teammates:
		if o == player or o.action == Player.Action.DOWN:
			continue
		if o.global_position.distance_to(carrier.global_position) < dist:
			closer.append(o)
	if not closer.is_empty() and not teammates.is_empty():
		var offset := player.global_position - carrier.global_position
		if absf(offset.y) > CONTAIN_LATERAL and dist > CONTAIN_ENGAGE:
			var aim_out := carrier.global_position + carrier.velocity * lead
			aim_out.y += signf(offset.y) * CONTAIN_OUT
			return _separate(_clamp_field(aim_out), closer)
		if offset.x * attack_dir > 6.0:  # à frente do portador: fecha o ângulo
			lead = minf(dist / speed, MAX_LEAD) * read * CUTOFF_LEAD
	var aim := carrier.global_position + carrier.velocity * lead
	return _separate(_clamp_field(aim), closer)


static func _clamp_field(aim: Vector2) -> Vector2:
	aim.y = clampf(aim.y, 0.0, FieldConstants.yards_to_px(FieldConstants.WIDTH_YARDS))
	return aim


## Quem já está mais perto do portador fica com o ponto; os outros desviam para o lado livre.
static func _separate(aim: Vector2, closer: Array[Player]) -> Vector2:
	for o in closer:
		var away := aim - o.global_position
		if away.length() < SEPARATION_RADIUS:
			var push := away.normalized() if away.length() > 0.5 else Vector2(0.0, 1.0)
			aim += push * SEPARATION_PUSH
	return _clamp_field(aim)
