class_name BlockSystem
extends Node
## Bloqueio estilo Tecmo. Cada bloqueador recebe do esquema da jogada um alvo, um atraso e uma duração;
## o confronto com o defensor é decidido por Hitting Power (principal), força e sorte. Filho do Match,
## criado antes dos jogadores para atualizar velocidade/empurrão antes de eles se moverem.

const STAND_OFF := 15.0
## Corpos se tocam a 14 px: abaixo disto o bloqueador encostou num defensor e engaja.
const ENGAGE_DISTANCE := 17.0
const ENGAGE_TIME := 0.15
const ENGAGE_SLOW := 0.2
## Perseguindo um alvo que escapou por mais tempo que isto, o bloqueador procura outro.
const CHASE_TIMEOUT := 2.5
const CONTEST_INTERVAL := 0.3
const START_GRIP := 0.5
const START_GRIP_PER_POINT := 0.004
const GRIP_BLOCKING := 0.5
const GRIP_LOSING := 0.25
## Desgaste do bloqueio: sem vantagem do bloqueador, ele cede aos poucos.
const GRIP_DECAY := 0.04
const GRIP_PER_POINT := 0.008
const MAX_EDGE := 40.0
const STRENGTH_WEIGHT := 0.25
const RANDOM_SPREAD := 15.0
const PUSH_SPEED := 48.0
const KNOCKBACK_SPEED := 60.0
const BROKEN_TIME := 0.35
const RECOVER_TIME := 0.5
const RELEASE_RECOVER_TIME := 0.15
## Depois de romper, o defensor não pode ser bloqueado de novo por este tempo.
const FREE_TIME := 1.2
const RETARGET_RANGE := 160.0
const RETARGET_INTERVAL := 0.25
## Retornos: defensor que passou do retornador por mais que isto deixa de ser alvo relevante.
const RELEVANCE_BEHIND := 24.0

## Ponto que o bloqueio protege (portador, QB ou ponto de queda do chute); definido pela partida.
var protect_fn: Callable
var active := false
var links: Array[BlockLink] = []
## Contadores para depuração/testes.
var breaks := 0
var releases := 0

var _defenders: Array[Player] = []
var _dir := 1.0
var _tactical := false
var _free_t: Dictionary = {}  # defensor -> tempo restante sem poder ser bloqueado
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


## Posição equivalente do outro lado do campo, usada para espelhar um esquema.
const MIRROR := {
	"LT": "RT", "RT": "LT", "LG": "RG", "RG": "LG", "LDE": "RDE", "RDE": "LDE", "LDT": "RDT", "RDT": "LDT",
	"LOLB": "ROLB", "ROLB": "LOLB", "LCB": "RCB", "RCB": "LCB", "FS": "SS", "SS": "FS",
	"WR1": "WR2", "WR2": "WR1", "TE": "WR3", "WR3": "TE", "C": "C", "MLB": "MLB",
}


## Monta os confrontos de um esquema. dir = direção de ataque de quem bloqueia; mirror espelha o esquema.
func begin(scheme_id: String, blockers: Array[Player], defenders: Array[Player], dir: float,
		mirror := false) -> void:
	clear()
	_defenders = defenders
	_dir = dir
	var scheme: Dictionary = BlockSchemes.SCHEMES[scheme_id]
	_tactical = scheme.get("tactical", false)
	if scheme.get("rank_match", false):
		var mine := _sorted_by_lane(blockers)
		var theirs := _sorted_by_lane(defenders)
		for i in mine.size():
			_add(mine[i], theirs[i] if i < theirs.size() else null,
					scheme["start"], scheme["duration"], scheme["drive"])
			links[-1].grip_cap = scheme.get("grip_cap", 1.0)
			links[-1].extra_decay = scheme.get("extra_decay", 0.0)
	else:
		var taken: Array[Player] = []
		for blocker in blockers:
			var spec: Variant = scheme["blockers"].get(MIRROR.get(blocker.role, blocker.role) if mirror else blocker.role)
			if spec == null:
				continue
			var roles: Array = spec["target"]
			var drive: Vector2 = spec["drive"]
			if mirror:
				roles = roles.map(func(r: String) -> String: return MIRROR.get(r, r))
				drive.y = -drive.y
			var target := _pick_target(roles, blocker, taken)
			taken.append(target)
			_add(blocker, target, spec["start"], spec["duration"], Vector2(drive.x * dir, drive.y))
	active = true


## Bloqueadores extras no meio da jogada (ex.: QB cruzou a linha): cada um procura o defensor livre mais próximo.
func add_blockers(blockers: Array[Player], duration: float) -> void:
	for b in blockers:
		_add(b, null, 0.0, duration, Vector2.ZERO)


func clear() -> void:
	release_all()
	_defenders = []
	_free_t.clear()
	breaks = 0
	releases = 0


## Solta todos: o efeito sobre os jogadores é desfeito e o sistema para.
func release_all() -> void:
	for link in links:
		_reset(link)
	links.clear()
	active = false


## Defensor travado no bloqueio (contato e domínio total do bloqueador): não consegue dar tackle.
func is_locked(defender: Player) -> bool:
	for link in links:
		if link.defender == defender and link.state in [BlockLink.State.ENGAGING, BlockLink.State.BLOCKING]:
			return true
	return false


func is_blocked(defender: Player) -> bool:
	for link in links:
		if link.defender == defender and link.is_engaged():
			return true
	return false


func _physics_process(delta: float) -> void:
	if not active:
		return
	for d in _free_t.keys():
		_free_t[d] -= delta
		if _free_t[d] <= 0.0:
			_free_t.erase(d)
	for link in links:
		_reset(link)
	var protect: Vector2 = protect_fn.call()
	for link in links:
		_step(link, protect, delta)


func _step(link: BlockLink, protect: Vector2, delta: float) -> void:
	var b := link.blocker
	if not is_instance_valid(b) or b.action == Player.Action.DOWN:
		return
	var d := link.defender
	link.time_in_state += delta
	match link.state:
		BlockLink.State.MOVING_TO_TARGET:
			_move_to_target(link, protect, delta)
		BlockLink.State.ENGAGING:
			if not _valid_target(d):
				_start_recovering(link, RELEASE_RECOVER_TIME)
				return
			b.input_dir = Vector2.ZERO
			_face(b, d)
			b.block_pose = "block"
			d.speed_scale = ENGAGE_SLOW
			if link.time_in_state >= ENGAGE_TIME:
				link.grip = minf(START_GRIP + clampf(_edge(b, d), -MAX_EDGE, MAX_EDGE) * START_GRIP_PER_POINT, link.grip_cap)
				link.contest_timer = 0.0
				link.set_state(_state_for_grip(link.grip))
		BlockLink.State.BLOCKING, BlockLink.State.FIGHTING_BLOCK, BlockLink.State.LOSING_BLOCK:
			_hold(link, protect, delta)
		BlockLink.State.BLOCK_BROKEN:
			b.input_dir = Vector2.ZERO
			b.block_pose = "beaten"
			if is_instance_valid(d):
				b.shove = (b.global_position - d.global_position).normalized() * KNOCKBACK_SPEED
			if link.time_in_state >= BROKEN_TIME:
				_start_recovering(link, RECOVER_TIME)
		BlockLink.State.RECOVERING:
			b.input_dir = Vector2.ZERO
			if link.time_in_state >= link.recover_time:
				link.defender = null
				link.delay = 0.0
				link.retarget_timer = 0.0
				link.set_state(BlockLink.State.MOVING_TO_TARGET)


func _move_to_target(link: BlockLink, protect: Vector2, delta: float) -> void:
	var b := link.blocker
	var touched := _touching_defender(link, protect)
	if touched != null:  # encostou em um defensor: engaja, mesmo que não fosse o alvo do esquema
		link.defender = touched
		link.set_state(BlockLink.State.ENGAGING)
		return
	var d := link.defender
	if _valid_target(d) and (_is_engaged_by_other(d, link) or not _is_relevant(d, protect)):
		link.defender = null
		d = null
	if link.delay > 0.0:
		link.delay -= delta
		link.time_in_state = 0.0
		b.input_dir = Vector2.ZERO
		return
	if not _valid_target(d):
		link.retarget_timer -= delta
		b.input_dir = Vector2.ZERO
		if link.retarget_timer <= 0.0:
			link.retarget_timer = RETARGET_INTERVAL
			link.defender = _pick_free(link, b.global_position, protect)
			link.time_in_state = 0.0
		return
	if b.global_position.distance_to(d.global_position) <= ENGAGE_DISTANCE:
		link.set_state(BlockLink.State.ENGAGING)
		return
	if link.time_in_state > CHASE_TIMEOUT:
		_start_recovering(link, RELEASE_RECOVER_TIME)
		return
	# Vai ao ponto entre o defensor e quem está sendo protegido.
	var to_spot := _block_spot(link, protect) - b.global_position
	b.input_dir = to_spot.normalized() if to_spot.length() > 2.0 else Vector2.ZERO
	_face(b, d)


func _hold(link: BlockLink, protect: Vector2, delta: float) -> void:
	var b := link.blocker
	var d := link.defender
	if not _valid_target(d):
		_start_recovering(link, RELEASE_RECOVER_TIME)
		return
	link.held += delta
	link.contest_timer += delta
	if link.contest_timer >= CONTEST_INTERVAL:
		link.contest_timer = 0.0
		link.grip += clampf(_edge(b, d), -MAX_EDGE, MAX_EDGE) * GRIP_PER_POINT - GRIP_DECAY - link.extra_decay
		link.grip = minf(link.grip, link.grip_cap)
		if link.grip <= 0.0:
			_break(link)
			return
		var new_state := _state_for_grip(link.grip)
		if new_state != link.state:
			link.set_state(new_state)
	if link.held >= link.duration:  # o bloqueio cumpriu o papel: solta o defensor
		releases += 1
		_free_t[d] = FREE_TIME
		_start_recovering(link, RELEASE_RECOVER_TIME)
		return
	# Engajados: os dois ficam parados em contato até o defensor se desvencilhar (rompimento).
	b.input_dir = Vector2.ZERO
	_face(b, d)
	b.block_pose = "block"
	d.speed_scale = 0.0
	# Nos esquemas com empurrão, quanto mais o bloqueador domina, mais o par desliza junto na direção do esquema.
	var push := clampf((link.grip - GRIP_LOSING) / (START_GRIP - GRIP_LOSING), 0.0, 1.0)
	d.shove = _drive(link, protect) * PUSH_SPEED * push
	b.shove = d.shove


## O defensor rompe o bloqueio: fica livre e o bloqueador cambaleia.
func _break(link: BlockLink) -> void:
	breaks += 1
	var d := link.defender
	_free_t[d] = FREE_TIME
	link.set_state(BlockLink.State.BLOCK_BROKEN)
	var fx := BreakEffect.new()
	fx.world_pos = (link.blocker.global_position + d.global_position) / 2.0
	get_parent().add_child(fx)


func _start_recovering(link: BlockLink, time: float) -> void:
	link.recover_time = time
	link.held = 0.0
	link.set_state(BlockLink.State.RECOVERING)


func _state_for_grip(grip: float) -> BlockLink.State:
	if grip > GRIP_BLOCKING:
		return BlockLink.State.BLOCKING
	if grip > GRIP_LOSING:
		return BlockLink.State.FIGHTING_BLOCK
	return BlockLink.State.LOSING_BLOCK


## Vantagem do bloqueador na disputa: Hitting Power é o principal, força ajuda, e há sorte.
func _edge(blocker: Player, defender: Player) -> float:
	return _score(blocker) - _score(defender)


func _score(p: Player) -> float:
	return p.attributes.hitting_power + p.attributes.strength * STRENGTH_WEIGHT \
			+ _rng.randf_range(-RANDOM_SPREAD, RANDOM_SPREAD)


func _drive(link: BlockLink, protect: Vector2) -> Vector2:
	if link.drive is Vector2:
		return link.drive
	var side := signf(link.defender.global_position.y - protect.y)  # "away": para fora do corredor
	return Vector2(0.0, side if side != 0.0 else 1.0)


## Onde o bloqueador fica: do lado oposto ao empurrão (abre o corredor); sem empurrão,
## entre o defensor e quem está sendo protegido.
func _block_spot(link: BlockLink, protect: Vector2) -> Vector2:
	var d := link.defender.global_position
	var drive := _drive(link, protect)
	if drive.length() > 0.1:
		return d - drive.normalized() * STAND_OFF
	return d + (protect - d).normalized() * STAND_OFF


func _face(from: Player, to: Player) -> void:
	from.facing = (to.global_position - from.global_position).normalized()


func _valid_target(d: Player) -> bool:
	return d != null and is_instance_valid(d) and d.action != Player.Action.DOWN


## Desfaz o efeito do confronto no frame anterior (o passo seguinte reaplica o que valer).
func _reset(link: BlockLink) -> void:
	if is_instance_valid(link.blocker):
		link.blocker.shove = Vector2.ZERO
		link.blocker.block_pose = ""
	if link.defender != null and is_instance_valid(link.defender):
		link.defender.shove = Vector2.ZERO
		link.defender.speed_scale = 1.0


func _add(blocker: Player, defender: Player, delay: float, duration: float, drive: Variant) -> void:
	var link := BlockLink.new()
	link.blocker = blocker
	link.defender = defender
	link.delay = delay
	link.duration = duration
	link.drive = drive
	links.append(link)


func _pick_target(roles: Array, blocker: Player, taken: Array[Player]) -> Player:
	for role in roles:
		for d in _defenders:
			if d.role == role and d not in taken:
				return d
	var free: Array[Player] = []
	for d in _defenders:
		if d not in taken:
			free.append(d)
	return _nearest(free if not free.is_empty() else _defenders, blocker.global_position, INF)


## Defensor que o bloqueador está encostando e que pode ser engajado.
func _touching_defender(link: BlockLink, protect: Vector2) -> Player:
	var free: Array[Player] = []
	for d in _defenders:
		if _valid_target(d) and not _free_t.has(d) and not _is_engaged_by_other(d, link) and _is_relevant(d, protect):
			free.append(d)
	return _nearest(free, link.blocker.global_position, ENGAGE_DISTANCE)


func _is_engaged_by_other(d: Player, except: BlockLink) -> bool:
	for other in links:
		if other != except and other.defender == d and other.is_engaged():
			return true
	return false


## Defensor livre mais próximo: não derrubado, não solto há pouco e sem outro bloqueador.
func _pick_free(link: BlockLink, from: Vector2, protect: Vector2) -> Player:
	var free: Array[Player] = []
	for d in _defenders:
		if _valid_target(d) and not _free_t.has(d) and not _is_taken(d, link) and _is_relevant(d, protect):
			free.append(d)
	return _nearest(free, from, RETARGET_RANGE)


## Nos retornos, só importa quem ainda está à frente do retornador (ou do ponto de queda).
func _is_relevant(d: Player, protect: Vector2) -> bool:
	return not _tactical or (d.global_position.x - protect.x) * _dir > -RELEVANCE_BEHIND


func _is_taken(d: Player, except: BlockLink) -> bool:
	for other in links:
		if other != except and other.defender == d and other.state != BlockLink.State.RECOVERING \
				and other.state != BlockLink.State.BLOCK_BROKEN:
			return true
	return false


func _nearest(players: Array[Player], from: Vector2, max_dist: float) -> Player:
	var best: Player = null
	var best_dist := max_dist
	for p in players:
		var dist := p.global_position.distance_to(from)
		if dist <= best_dist:
			best = p
			best_dist = dist
	return best


## Ordem lateral (esquerda -> direita), usada para casar bloqueadores e cobertura nos retornos.
func _sorted_by_lane(players: Array[Player]) -> Array[Player]:
	var sorted := players.duplicate()
	sorted.sort_custom(func(a: Player, b: Player) -> bool:
		return a.position.y < b.position.y or (a.position.y == b.position.y and a.position.x < b.position.x))
	return sorted
