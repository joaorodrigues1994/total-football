class_name QbBrain
extends RefCounted
## Decisão do QB da CPU durante o bolso: avalia os recebedores a cada poucos décimos de segundo e escolhe
## entre lançar, esperar, escapar da pressão ou correr (scramble). O tempo de espera é só um teto de paciência.
## Atributos usados (sem criar novos): pass_accuracy (precisão/controle), agility e speed (mobilidade),
## receiving do recebedor.

enum Action { WAIT, THROW, ESCAPE, SCRAMBLE }

const EVAL_INTERVAL := 0.15
## Paciência (s) sem opção boa; cai com a pressão. O limite duro força uma decisão.
const PATIENCE := 1.8
const HARD_LIMIT := 2.2
const MIN_PATIENCE := 0.5
## Nota mínima para lançar de imediato; sobe com baixa precisão e cai com pressão.
const BASE_THRESHOLD := 0.62
const PRESSURE_THRESHOLD_DROP := 0.32
const ACCURACY_THRESHOLD_SLOPE := 0.003
## Nota aceitável quando a paciência acaba.
const ACCEPTABLE_SCORE := 0.28
const RISKY_SCORE_CAP := 0.15
## Pressão: defensor solto a esta distância (px) começa a pressionar; a distância pequena é pressão total.
const PRESSURE_RANGE := 96.0
const FULL_PRESSURE_DISTANCE := 28.0
const ESCAPE_PRESSURE := 0.45
const FORCED_PRESSURE := 0.85
const ESCAPE_MAX_TIME := 1.0
## (agility + speed) / 2 mínimo para escapar do bolso ou correr.
const MOBILE_MIN := 40
## Folga (s) entre a bola chegar e o defensor alcançá-la: abaixo de MIN_LEAD é risco, acima de OPEN_LEAD é livre.
const MIN_LEAD := -0.2
const OPEN_LEAD := 0.8
const AHEAD_SPACE := 120.0
const SCRAMBLE_SPACE := 70.0
const SCRAMBLE_LANE_WIDTH := 40.0

var elapsed := 0.0

var _timer := 0.0
var _escape_time := 0.0
var _last := {"action": Action.WAIT}


func reset() -> void:
	elapsed = 0.0
	_timer = 0.0
	_escape_time = 0.0
	_last = {"action": Action.WAIT}


## Chamado a cada frame com o QB no bolso. Retorna {"action": Action, "index": alvo, "dir": direção de escape}.
func think(delta: float, qb: Player, receivers: Array[Player], runners: Array[RouteRunner],
		defenders: Array[Player], blocks: BlockSystem, dir: float) -> Dictionary:
	elapsed += delta
	_timer += delta
	if _timer < EVAL_INTERVAL:
		return _last
	_timer = 0.0
	var pressure := pressure_on(qb, defenders, blocks)
	var best := 0
	var best_score := -1.0
	for i in receivers.size():
		var score := evaluate(qb, receivers[i], runners[i], defenders, blocks, dir)
		if score > best_score:
			best_score = score
			best = i
	var accuracy := float(qb.attributes.pass_accuracy)
	var threshold := BASE_THRESHOLD - pressure * PRESSURE_THRESHOLD_DROP + (50.0 - accuracy) * ACCURACY_THRESHOLD_SLOPE
	var patience := lerpf(PATIENCE, MIN_PATIENCE, pressure)
	var limit := lerpf(HARD_LIMIT, MIN_PATIENCE + 0.3, pressure)
	var mobile := mobility(qb) >= MOBILE_MIN
	var scramble_dir := _scramble_lane(qb, defenders, dir)
	var action := Action.WAIT
	if best_score >= threshold:
		action = Action.THROW
	elif pressure >= FORCED_PRESSURE or elapsed >= limit:
		if best_score >= ACCEPTABLE_SCORE:
			action = Action.THROW
		elif mobile and scramble_dir != Vector2.ZERO:
			action = Action.SCRAMBLE
		else:
			action = Action.THROW
	elif elapsed >= patience and best_score >= ACCEPTABLE_SCORE:
		action = Action.THROW
	elif pressure >= ESCAPE_PRESSURE and mobile and _escape_time < ESCAPE_MAX_TIME:
		action = Action.ESCAPE
		_escape_time += EVAL_INTERVAL
	_last = {"action": action, "index": best, "dir": _escape_direction(qb, defenders, blocks, dir), "scramble_dir": scramble_dir, "score": best_score, "pressure": pressure}
	return _last


## Nota de 0 a 1 do passe para o recebedor: prevê onde ele estará quando a bola chegar e se algum defensor
## consegue chegar ao ponto antes. Defensor travado em bloqueio não alcança.
static func evaluate(qb: Player, receiver: Player, runner: RouteRunner, defenders: Array[Player],
		blocks: BlockSystem, dir: float) -> float:
	var from := qb.global_position
	var receiver_speed := FieldConstants.yards_to_px(receiver.attributes.max_speed_yards())
	var aim := receiver.global_position
	var t := from.distance_to(aim) / Match.BALL_SPEED
	for i in 3:  # o ponto de chegada depende do tempo de voo e vice-versa
		aim = runner.position_after(t, receiver_speed)
		t = from.distance_to(aim) / Match.BALL_SPEED
	var lead := INF
	var ahead := INF
	for d in defenders:
		if d.action == Player.Action.DOWN or blocks.is_blocked(d):
			continue
		var speed := FieldConstants.yards_to_px(d.attributes.max_speed_yards())
		var future := d.global_position + d.velocity * 0.2
		var reach := maxf(future.distance_to(aim) - Match.CATCH_RADIUS, 0.0) / speed
		lead = minf(lead, reach - t)
		if (d.global_position.x - aim.x) * dir > 0.0:
			ahead = minf(ahead, d.global_position.distance_to(aim))
	var separation := clampf((lead - MIN_LEAD) / (OPEN_LEAD - MIN_LEAD), 0.0, 1.0)
	var room := clampf(ahead / AHEAD_SPACE, 0.0, 1.0)
	var distance_yards := from.distance_to(aim) / FieldConstants.PX_PER_YARD
	var score := separation * (0.75 + 0.25 * room)
	score += (receiver.attributes.receiving - 50) * 0.003
	score -= distance_yards * lerpf(0.010, 0.003, qb.attributes.pass_accuracy / 100.0)
	if lead < 0.0:  # o defensor chega antes da bola: risco alto de interceptação
		score = minf(score, RISKY_SCORE_CAP)
	return clampf(score + minf(lead, 0.0) * 0.3, -1.0, 1.0)  # coberto: ainda ordena quem está menos coberto


## 0 a 1: quão perto está o defensor solto (sem bloqueador) mais próximo do QB.
static func pressure_on(qb: Player, defenders: Array[Player], blocks: BlockSystem) -> float:
	var nearest := INF
	for d in defenders:
		if d.action == Player.Action.DOWN or blocks.is_blocked(d):
			continue
		nearest = minf(nearest, d.global_position.distance_to(qb.global_position))
	return clampf(inverse_lerp(PRESSURE_RANGE, FULL_PRESSURE_DISTANCE, nearest), 0.0, 1.0)


static func mobility(qb: Player) -> float:
	return (qb.attributes.agility + qb.attributes.speed) / 2.0


## Foge do defensor solto mais próximo, sem avançar em direção à linha de scrimmage (isso é o scramble).
func _escape_direction(qb: Player, defenders: Array[Player], blocks: BlockSystem, dir: float) -> Vector2:
	var nearest: Player = null
	var best := INF
	for d in defenders:
		if d.action == Player.Action.DOWN or blocks.is_blocked(d):
			continue
		var dist := d.global_position.distance_to(qb.global_position)
		if dist < best:
			best = dist
			nearest = d
	if nearest == null:
		return Vector2.ZERO
	var away := (qb.global_position - nearest.global_position).normalized()
	if away.x * dir > 0.0:
		away.x = 0.0
	if absf(away.y) < 0.2:  # sem lado claro: vai para onde há mais campo
		away.y = 1.0 if qb.global_position.y < FieldConstants.yards_to_px(FieldConstants.WIDTH_YARDS) / 2.0 else -1.0
	return away.normalized()


## Direção de corrida com o corredor livre de defensores (qualquer um conta: bloqueados também são obstáculo).
## Prefere em frente; senão diagonal. Vector2.ZERO = sem espaço.
func _scramble_lane(qb: Player, defenders: Array[Player], dir: float) -> Vector2:
	var toward_field := 1.0 if qb.global_position.y < FieldConstants.yards_to_px(FieldConstants.WIDTH_YARDS) / 2.0 else -1.0
	for lane_y in [0.0, toward_field * 0.6, -toward_field * 0.6]:
		var v := Vector2(dir, lane_y).normalized()
		var free := true
		for d in defenders:
			if d.action == Player.Action.DOWN:
				continue
			var offset := d.global_position - qb.global_position
			var along := offset.dot(v)
			if along > 0.0 and along < SCRAMBLE_SPACE * 2.0 and absf(offset.cross(v)) < SCRAMBLE_LANE_WIDTH:
				free = false
				break
		if free:
			return v
	return Vector2.ZERO
