extends SceneTree
## Suíte de medição do bloqueio, corrida e pressão (headless, descartável no sentido de não ser usada pelo jogo).
## Uso: Godot --headless --path . -s tests/block_suite.gd -- <modo> <n> [hp_defensor]
##   duel <n> [hp] [extra_decay] : n duelos 1x1 LT x LDE (pass_short) com o HP do defensor dado; mede fração de rompimentos e tempo
##   (último argumento opcional: base das sementes)
##   pass <n> [up|down|left|right] : n passes da CPU contra a jogada defensiva escolhida (padrão up = RUSH 4)
##   run  <n>       : n corridas da CPU contra BASE
## Sementes fixas por jogada (comparação pareada antes/depois).

const PLAYER_SCENE := preload("res://scenes/player.tscn")


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0]
	var n := int(args[1])
	if mode == "duel":
		await _duel(n, int(args[2]) if args.size() > 2 else -1, float(args[3]) if args.size() > 3 else -1.0)
	else:
		await _match_mode(mode, n, args[2] if args.size() > 2 else "up", int(args[3]) if args.size() > 3 else 0)
	quit()


func _duel(n: int, hp: int, decay: float) -> void:
	var world := Node2D.new()
	root.add_child(world)
	await _frames(2)
	Engine.time_scale = 4.0
	var broke := 0
	var times: Array[float] = []
	var done := 0
	var batch := 20
	var seed_i := 0
	while done < n:
		var duels: Array = []
		for i in batch:
			seed_i += 1
			var y := 30.0 + i * 28.0
			var lt: Player = PLAYER_SCENE.instantiate()
			lt.role = "LT"
			lt.attributes = PlayerAttributes.for_role("LT")
			lt.position = Vector2(500, y)
			var de: Player = PLAYER_SCENE.instantiate()
			de.role = "LDE"
			de.team = Player.Team.B
			de.attributes = PlayerAttributes.for_role("LDE")
			if hp > 0:
				de.attributes.hitting_power = hp
			de.position = Vector2(530, y)
			world.add_child(lt)
			world.add_child(de)
			var bs := BlockSystem.new()
			bs._rng.seed = seed_i
			var qb := Vector2(400, y)
			bs.protect_fn = func() -> Vector2: return qb
			world.add_child(bs)
			var ldef: Array[Player] = [de]
			var lblk: Array[Player] = [lt]
			bs.begin("pass_short", lblk, ldef, 1.0)
			if decay >= 0.0:  # calibração: sobrepõe o desgaste extra do esquema
				for l in bs.links:
					l.extra_decay = decay
			duels.append({"bs": bs, "lt": lt, "de": de, "t": 0.0, "first": -1.0})
		var t := 0.0
		while t < 6.0:
			await physics_frame
			var dt: float = root.get_physics_process_delta_time()
			t += dt
			for d in duels:
				d["t"] = t
				if d["first"] < 0.0 and d["bs"].breaks > 0:
					d["first"] = t
		for d in duels:
			if d["first"] >= 0.0 and d["first"] <= 5.0:
				broke += 1
				times.append(d["first"])
			d["bs"].queue_free()
			d["lt"].queue_free()
			d["de"].queue_free()
		done += batch
		await _frames(2)
	var mean := 0.0
	for v in times:
		mean += v
	print("RES duel hp=", hp, " n=", done, " rompeu_em_5s=", snappedf(float(broke) / done, 0.001),
			" t_medio_1o_rompimento=", snappedf(mean / maxf(times.size(), 1), 0.01))


func _match_mode(mode: String, n: int, pick: String, seed_base: int) -> void:
	var s = load("res://scenes/main.tscn").instantiate()
	root.add_child(s)
	var m: Match = s.get_node("Match")
	await _frames(5)
	Engine.time_scale = 4.0
	var action := "btn_s" if mode == "pass" else "btn_a"
	var done := 0
	var tries := 0
	var acc := {}
	var gains: Array[float] = []
	while done < n and tries < n * 3:
		tries += 1
		m.rules.start_drive(1, 40.0)
		m._setup()
		m.rules.rng.seed = tries + seed_base
		m._block_system._rng.seed = tries + seed_base
		m._carrier_brain._rng.seed = tries + seed_base
		await _frames(3)
		Input.action_press("ui_" + pick)
		Input.action_press(action)
		await _frames(4)
		Input.action_release("ui_" + pick)
		Input.action_release(action)
		var seen := false
		var t := 0.0
		var elapsed := 0.0
		var first_break := -1.0
		var eng_sum := 0.0
		var eng_n := 0
		var pinched := 0
		var run_frames := 0
		var x0 := 0.0
		var dir := 1.0
		var lastc: Player = null
		var thrown_at := -1.0
		while t < 25.0 and m.state != Match.State.DEAD:
			await physics_frame
			var dt: float = root.get_physics_process_delta_time()
			t += dt
			var st := m.state
			if mode == "pass":
				if st == Match.State.DROPBACK or st == Match.State.PASSING:
					seen = true
					elapsed += dt
					var e := 0
					for d in m.defense:
						if m._block_system.is_blocked(d):
							e += 1
					eng_sum += e
					eng_n += 1
					if first_break < 0.0 and m._block_system.breaks > 0:
						first_break = elapsed
				if st == Match.State.FLIGHT and thrown_at < 0.0:
					thrown_at = elapsed
					break
			elif st == Match.State.RUNNING:
				if not seen:
					seen = true
					x0 = m.scrimmage_spot.x
					dir = m.attack_dir
				var c = m._carrier
				lastc = c
				run_frames += 1
				var maxs: float = FieldConstants.yards_to_px(c.attributes.max_speed_yards())
				if c.velocity.length() < 0.35 * maxs and c.input_dir.length() > 0.5:
					for o in m.offense:
						if o != c and o.global_position.distance_to(c.global_position) < 15.5:
							pinched += 1
							break
		if not seen:
			continue
		if mode == "run":
			if m.play_type != Match.PlayType.RUN or lastc == null:
				continue
			var near := 0
			var clustered := 0
			for d in m.defense:
				if d.global_position.distance_to(lastc.global_position) < 40.0:
					near += 1
				for d2 in m.defense:
					if d2 != d and d.global_position.distance_to(d2.global_position) < 16.0:
						clustered += 1
						break
			var gain := (lastc.global_position.x - x0) * dir / 12.0
			gains.append(gain)
			acc["jardas"] = acc.get("jardas", 0.0) + gain
			acc["corridas_10mais"] = acc.get("corridas_10mais", 0.0) + (1.0 if gain >= 10.0 else 0.0)
			acc["corridas_perda"] = acc.get("corridas_perda", 0.0) + (1.0 if gain < 0.0 else 0.0)
			acc["tempo_corrida_s"] = acc.get("tempo_corrida_s", 0.0) + m._running_time
			acc["travado_por_aliado"] = acc.get("travado_por_aliado", 0.0) + float(pinched) / maxf(run_frames, 1)
			acc["defensores_a_40px"] = acc.get("defensores_a_40px", 0.0) + near
			acc["defensores_agrupados"] = acc.get("defensores_agrupados", 0.0) + clustered
			acc["rompimentos"] = acc.get("rompimentos", 0.0) + m._block_system.breaks
		else:
			acc["engajados_medio"] = acc.get("engajados_medio", 0.0) + eng_sum / maxf(eng_n, 1)
			acc["rompimentos"] = acc.get("rompimentos", 0.0) + m._block_system.breaks
			acc["com_rompimento"] = acc.get("com_rompimento", 0.0) + (1.0 if first_break >= 0.0 else 0.0)
			acc["t_1o_rompimento"] = acc.get("t_1o_rompimento", 0.0) + (first_break if first_break >= 0.0 else 0.0)
			acc["t_lancamento"] = acc.get("t_lancamento", 0.0) + (thrown_at if thrown_at >= 0.0 else elapsed)
			acc["sack"] = acc.get("sack", 0.0) + (1.0 if m.play_result == "sack" else 0.0)
		done += 1
	var out := {}
	for k in acc:
		out[k] = snappedf(acc[k] / maxf(done, 1), 0.01)
	gains.sort()
	if not gains.is_empty():
		out["mediana"] = snappedf(gains[gains.size() / 2], 0.1)
		out["max"] = snappedf(gains[-1], 0.1)
	print("RES ", mode, " ", pick, " n=", done, " ", out)
