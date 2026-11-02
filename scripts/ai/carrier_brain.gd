class_name CarrierBrain
extends RefCounted
## IA do portador da CPU (RB, retornador, interceptador, QB em scramble): escolhe a faixa mais livre à frente,
## desvia de defensores, finta quando alguém está para pegá-lo e mergulha perto da goal line.
## Atributos usados (sem criar novos): agility (desvio e finta), speed (alcance da leitura),
## strength (aceita contato em vez de desviar).

const EVAL_INTERVAL := 0.1
const ANGLES := [-65.0, -40.0, -20.0, 0.0, 20.0, 40.0, 65.0]
const LANE_WIDTH := 22.0
const BASE_LOOK_AHEAD := 90.0
## Peso do risco de cada faixa e do custo de desviar; interpolados pelos atributos.
const RISK_WEIGHT_WEAK := 2.2
const RISK_WEIGHT_STRONG := 1.2
const TURN_COST_CLUMSY := 0.35
const TURN_COST_AGILE := 0.1
const KEEP_BONUS := 0.15
## Parados em bloqueio ainda atrapalham o caminho, mas não vão atrás do portador.
const BLOCKED_RISK := 0.6
const PREDICT_TIME := 0.3
## Aliados (bloqueadores): o corpo tem 14 px, então a faixa livre precisa de uns 18 px de cada lado do centro.
const ALLY_LANE_WIDTH := 18.0
const ALLY_WALL_RISK := 0.9
const ALLY_MOVING_RISK := 0.3
const JUKE_RANGE := 42.0
## Depois da finta o portador corta para o lado por este tempo (o corpo do defensor bloqueia o caminho).
const DODGE_TIME := 0.4
const JUKE_CHANCE_BASE := 0.3
const JUKE_CHANCE_AGILITY := 0.5
const GOAL_ZONE := 72.0
const DIVE_RANGE := 30.0
const DIVE_DISTANCE := 26.0

var _timer := 0.0
var _dir := Vector2.ZERO
var _juke := false
var _dive := false
var _dodge_time := 0.0
var _dodge_dir := Vector2.ZERO
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


## Começa uma corrida nova; hint é a direção inicial (para a frente se vazio).
func reset(hint := Vector2.ZERO) -> void:
	_timer = EVAL_INTERVAL
	_dir = hint
	_juke = false
	_dive = false
	_dodge_time = 0.0


## Chamado a cada frame. Retorna {"dir": Vector2, "juke": bool, "dive": bool} (juke/dive valem só uma vez).
func think(delta: float, carrier: Player, defenders: Array[Player], allies: Array[Player], blocks: BlockSystem,
		forward: float, goal_x: float) -> Dictionary:
	_timer += delta
	_dodge_time = maxf(_dodge_time - delta, 0.0)
	if _timer >= EVAL_INTERVAL:
		_timer = 0.0
		_decide(carrier, defenders, allies, blocks, forward, goal_x)
	var result := {"dir": _dodge_dir if _dodge_time > 0.0 else _dir, "juke": _juke, "dive": _dive}
	_juke = false
	_dive = false
	return result


func _decide(carrier: Player, defenders: Array[Player], allies: Array[Player], blocks: BlockSystem,
		forward: float, goal_x: float) -> void:
	var attrs := carrier.attributes
	var look := BASE_LOOK_AHEAD + attrs.speed * 0.8
	var risk_weight := lerpf(RISK_WEIGHT_WEAK, RISK_WEIGHT_STRONG, attrs.strength / 100.0)
	var turn_cost := lerpf(TURN_COST_CLUMSY, TURN_COST_AGILE, attrs.agility / 100.0)
	var to_goal := (goal_x - carrier.global_position.x) * forward
	var in_goal_zone := to_goal < GOAL_ZONE
	var best_score := -INF
	var best := Vector2(forward, 0.0)
	for angle in ANGLES:
		if in_goal_zone and absf(angle) > 40.0:  # perto do touchdown: segue para a endzone
			continue
		var v := Vector2(forward, 0.0).rotated(deg_to_rad(angle) * forward)
		var risk := maxf(_lane_risk(carrier, v, look, defenders, blocks), _ally_risk(carrier, v, look, allies))
		var score := v.x * forward * (2.0 if in_goal_zone else 1.0) - risk * risk_weight - absf(angle) / 90.0 * turn_cost * 2.0
		if _dir != Vector2.ZERO and v.dot(_dir) > 0.97:
			score += KEEP_BONUS
		if score > best_score:
			best_score = score
			best = v
	_dir = best
	var threat := _nearest_free_threat(carrier, defenders, blocks)
	if threat != null:
		var dist := threat.global_position.distance_to(carrier.global_position)
		if in_goal_zone and to_goal < DIVE_DISTANCE and dist < DIVE_RANGE:
			_dive = true
		elif dist < JUKE_RANGE and _rng.randf() < JUKE_CHANCE_BASE + JUKE_CHANCE_AGILITY * attrs.agility / 100.0:
			_juke = true
			var side := signf(carrier.global_position.y - threat.global_position.y)
			if side == 0.0:
				side = 1.0 if carrier.global_position.y < FieldConstants.yards_to_px(FieldConstants.WIDTH_YARDS) / 2.0 else -1.0
			_dodge_dir = Vector2(forward * 0.6, side).normalized()
			_dodge_time = DODGE_TIME


## 0 a 1: quão ocupada está a faixa na direção v (defensores à frente dentro da largura da faixa).
func _lane_risk(carrier: Player, v: Vector2, look: float, defenders: Array[Player], blocks: BlockSystem) -> float:
	var risk := 0.0
	for d in defenders:
		if d.action == Player.Action.DOWN:
			continue
		var free := not blocks.is_blocked(d)
		var pos := d.global_position + (d.velocity * PREDICT_TIME if free else Vector2.ZERO)
		var offset := pos - carrier.global_position
		var along := offset.dot(v)
		if along < 0.0 or along > look:
			continue
		var side := absf(offset.cross(v))
		if side > LANE_WIDTH:
			continue
		var proximity := (1.0 - along / look) * (1.0 - side / LANE_WIDTH * 0.5)
		risk = maxf(risk, proximity * (1.0 if free else BLOCKED_RISK))
	return risk


## Aliados no caminho: bloqueadores engajados são paredes paradas (risco cheio); os que se movem pesam menos.
func _ally_risk(carrier: Player, v: Vector2, look: float, allies: Array[Player]) -> float:
	var risk := 0.0
	for a in allies:
		if a == carrier or a.action == Player.Action.DOWN:
			continue
		var offset := a.global_position - carrier.global_position
		var along := offset.dot(v)
		if along < 0.0 or along > look:
			continue
		var side := absf(offset.cross(v))
		if side > ALLY_LANE_WIDTH:
			continue
		var wall := a.block_pose == "block" or a.velocity.length() < 5.0
		risk = maxf(risk, (1.0 - along / look) * (1.0 - side / ALLY_LANE_WIDTH * 0.5) * (ALLY_WALL_RISK if wall else ALLY_MOVING_RISK))
	return risk


func _nearest_free_threat(carrier: Player, defenders: Array[Player], blocks: BlockSystem) -> Player:
	var best: Player = null
	var best_dist := INF
	for d in defenders:
		if d.action == Player.Action.DOWN or blocks.is_blocked(d):
			continue
		var dist := d.global_position.distance_to(carrier.global_position)
		if dist < best_dist:
			best_dist = dist
			best = d
	return best
