extends SceneTree

const Rune = preload("res://scripts/power_rune.gd")
const Settings = preload("res://scripts/settings.gd")
const Simulation = preload("res://scripts/simulation.gd")
const Assist = preload("res://scripts/aim_assist.gd")
var checks = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)


func complete(rune: RefCounted, double_hits: bool, radius: float = 0.0) -> void:
	for _group in range(5):
		if rune.blackout_end != INF:
			rune.advance(rune.blackout_end + 0.00001)
		check(not rune.targets.is_empty(), "new group supplies a target")
		if rune.targets.is_empty():
			return
		check(rune.receive_hit(rune.targets[0], radius, rune.time).accepted, "first blade accepts physical radial hit")
		if rune.big and rune.rules.paired_big:
			if double_hits:
				check(rune.receive_hit(rune.targets[0], radius, rune.time + 0.00001).accepted, "second blade accepted within 1s")
			else:
				rune.advance(rune.second_end + 0.00001)


func run() -> void:
	for kind in ["small_rune_2025", "big_rune_2025", "small_rune_2027", "big_rune_2027"]:
		var rune = Rune.new()
		rune.reset(kind)
		var selected_big: bool = rune.big
		rune.advance(600.0)
		check(rune.state == "ready" and rune.targets.is_empty(), "no automatic activation before button: " + kind)
		check(rune.big == selected_big, "selected size does not change at3min or7min: " + kind)
		check(rune.start(600.0) and rune.state == "active", "one click starts immediately after old match end: " + kind)
		check(rune.targets.size() == (2 if rune.big and rune.rules.paired_big else 1), "button immediately lights the seasonal target count: " + kind)
		check(rune.a >= 0.780 and rune.a <= 1.045 and rune.omega >= 1.884 and rune.omega <= 2.000, "official randomized motion parameters")
		if rune.big:
			var expected: float = rune.angle + rune.direction * (rune.a / rune.omega * (1 - cos(rune.omega)) + 2.09 - rune.a)
			check(absf(rune.phase(601.0) - expected) < 1e-10, "practice start preserves official speed integration")
		else:
			check(is_equal_approx(absf(rune.speed(rune.time)), PI / 3), "small practice speed remains constant")
		check(not rune.receive_hit(rune.targets[0], 0.151, rune.time).accepted, "physical annulus outside300mm detector ignored")
		var wrong: int = 0
		while wrong in rune.targets:
			wrong += 1
		var epoch: float = rune.epoch
		var amplitude: float = rune.a
		check(rune.receive_hit(wrong, 0, rune.time).outcome == "wrong_blade", "unlit blade resets progress")
		check(rune.epoch == epoch and rune.a == amplitude, "wrong hit does not reset this attempt's motion law")
		if rune.blackout_end != INF:
			rune.advance(rune.blackout_end + 0.00001)
		rune.advance(rune.target_end + 0.00001)
		check(rune.last_outcome == "target_timeout" and rune.groups == 0 and rune.state == "active", "2.5s miss retries without requiring another button")
		rune.advance(rune.time + 35.0)
		check(rune.state == "active", "practice attempt has no match-level20/30s cutoff")
		check(rune.start(rune.time) and rune.groups == 0 and rune.hits == 0, "button can restart an active attempt")
		complete(rune, rune.rules.paired_big)
		check(rune.state == "activated" and rune.groups == 5, "five groups complete practice attempt")
		if rune.year == 2025:
			var seen: Dictionary = {}
			for index in rune.completed:
				seen[index] = true
			check(seen.size() == 5 and rune.hits == 5, "2025 completes five different single blades")
			if rune.big:
				check(rune.benefit.total_ring == 50 and rune.benefit.attack_percent == 500 and rune.benefit.defense_percent == 50, "2025 five bullseyes retain official total-ring reward")
				check(is_equal_approx(rune.detection_radius(), 0.15), "2025 detector does not shrink")
			else:
				check(rune.benefit.extra_experience_cap == 800 and rune.benefit.structure_defense_percent == 75, "2025 small reward retained as diagnostics")
		elif rune.big:
			check(rune.hits == 10 and rune.benefit.duration == 60 and rune.benefit.average_ring == 10, "2027 five pairs retain average-ring and ten-hit reward")
			check(is_equal_approx(rune.detection_radius(), 0.105), "2027 first success still shrinks effective detector")
		check(rune.start(rune.time) and rune.state == "active" and rune.benefit.is_empty(), "button bypasses benefit cooldown immediately")
		check(Settings.load_file("res://configs/" + kind + ".cfg").ok, "season config validates: " + kind)

	var big = Rune.new()
	big.reset("big_rune_2027")
	big.start(0)
	check(big.targets[0] != big.targets[1], "2027 paired targets remain distinct")
	complete(big, true)
	big.start(big.time)
	check(not big.receive_hit(big.targets[0], 0.106, big.time).accepted, "outside shrunken detector cannot trigger")
	complete(big, false, 0.105)
	check(big.state == "activated" and big.hits == 5 and big.benefit.duration == 30, "optional second hits may time out without failing group")
	check(big.benefit.average_ring == 4 and is_equal_approx(big.detection_radius(), 0.060), "second activation retains ring4 boundary and further shrink")
	big.start(big.time)
	complete(big, false, 0.060)
	check(big.benefit.average_ring == 7, "60mm boundary is ring7")

	for row in [[1, 150, 25], [3, 150, 25], [5, 155, 25], [7, 160, 25], [8, 200, 25], [9, 300, 25], [10, 500, 50]]:
		var scored = Rune.new()
		scored.reset("big_rune_2025")
		scored.start(0)
		for _blade in range(5):
			var radius: float = (10 - row[0]) * 0.015 + 0.001
			scored.receive_hit(scored.targets[0], radius, scored.time)
		check(scored.benefit.attack_percent == row[1] and scored.benefit.defense_percent == row[2], "2025 official total-ring reward tier: " + str(row[0] * 5))

	var loaded = Settings.load_file("res://configs/small_rune_2027.cfg")
	check(loaded.ok, "small rune config validates")
	check(Settings.load_file("res://configs/big_rune_2027.cfg").ok, "big rune config validates")
	var s = loaded.settings
	s.target.translate = true
	s.target.rotate = true
	s.target.omega = 25.0
	var sim = Simulation.new(s)
	var center: Vector3 = sim.rune_center()
	check(sim.camera_observation().armors.is_empty() and sim.snapshot().truth.armors.is_empty(), "rune publishes no ghost armor observations")
	check(sim.snapshot().mode == 2, "small feedback mode is2")
	sim.set_command({"control": true, "fire": false, "yaw": 0.5, "pitch": 0})
	sim.step(0.1)
	check(sim.target_pose(sim.time).center.is_equal_approx(center), "armor translation/rotation and live camera motion do not move rune")
	check(is_equal_approx(absf(sim.rune.speed(sim.time)), PI / 3), "armor omega cannot overwrite official rune speed")
	var turned = s.duplicate(true)
	turned.rune.heading = PI / 2
	turned.rune.lateral = 1.0
	sim.apply_settings(turned)
	check(sim.rune_basis().z.is_equal_approx(Vector3(0,-1,0)), "heading changes the stationary rune plane normal")
	check(is_equal_approx(sim.rune_center().y, 1.0), "left offset independent from armor center")
	var roundtrip = "user://rune_roundtrip.cfg"
	check(Settings.save_file(turned, roundtrip) == OK and Settings.load_file(roundtrip).ok, "independent settings serialize and reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(roundtrip))
	var firing = Settings.defaults()
	firing.appearance.robot = "small_rune_2027"
	firing.rune.height = 1.5
	firing.weapon.rate = 2.0
	var physical = Simulation.new(firing)
	physical.rune.start(0)
	for i in range(480):
		var solution = Assist.solve(physical)
		if not solution.is_empty():
			physical.set_command({"control": true, "fire": true, "yaw": solution.yaw, "pitch": solution.pitch,
				"yaw_vel": solution.yaw_vel, "pitch_vel": solution.pitch_vel})
		physical.step(1.0 / 240)
	check(physical.stats.hit > 0, "normal launch, ballistic flight and moving circular collision activate a blade")
	check(physical.stats.damage == 0 and physical.stats.kills == 0, "rune hits do not apply armor HP damage")
	var switching = Simulation.new(Settings.defaults())
	switching.set_command({"control": true, "fire": true, "yaw": 0.0, "pitch": 0.0})
	switching.step(0.02)
	check(switching.metrics().in_flight > 0, "normal firing creates a bullet before switching target")
	var changed = switching.settings.duplicate(true)
	changed.appearance.robot = "big_rune_2025"
	var previous_session: String = switching.session_id
	switching.apply_settings(changed)
	var totals = switching.metrics()
	check(totals.in_flight == 0 and totals.expired > 0 and totals.fired == totals.resolved, "target switch settles removed bullets without losing cumulative accounting")
	check(switching.session_id != previous_session and not switching.command.fire and switching.pending.is_empty(), "target switch invalidates old commands and launch queue")

	var switch_K: Array = switching.camera_observation().K.duplicate()
	var aim: Dictionary = switching.camera_pose()
	check(aim.forward.dot((switching.rune_center() - aim.origin).normalized()) > 1.0 - 1e-6,
		"armor to rune frames the new target without changing calibration")
	switching.yaw = 0.3
	switching.pitch = -0.1
	changed.appearance.robot = "small_rune_2025"
	switching.apply_settings(changed)
	check(switching.yaw == 0.3 and switching.pitch == -0.1, "switching within the rune category retains the view")
	switching.yaw_velocity = 1.0
	switching.pitch_velocity = -1.0
	changed.appearance.robot = "infantry_3_2026"
	var switch_time: float = switching.time
	var switch_stats: Dictionary = switching.stats.duplicate()
	switching.apply_settings(changed)
	aim = switching.camera_pose()
	check(aim.forward.dot((switching.target_pose(switching.time).center - aim.origin).normalized()) > 1.0 - 1e-6,
		"rune to armor frames the new target without a manual reset")
	check(switching.yaw_velocity == 0.0 and switching.pitch_velocity == 0.0,
		"reframing clears residual gimbal velocity")
	check(not switching.camera_observation().armors.is_empty(), "returning armor is inside the camera image")
	check(switching.time == switch_time and switching.stats == switch_stats,
		"reframing preserves running time and cumulative statistics")
	check(switching.camera_observation().K == switch_K, "reframing does not alter intrinsics")
	switching.yaw = -0.2
	switching.pitch = 0.1
	changed.appearance.robot = "infantry_4_2026"
	switching.apply_settings(changed)
	check(switching.yaw == -0.2 and switching.pitch == 0.1, "switching within the armor category retains the view")

	var legacy = ConfigFile.new()
	var legacy_path = "user://legacy_season.cfg"
	for pair in [["infantry_3", "infantry_3_2026"], ["hero", "hero_2026"], ["sentry", "sentry_2026"], ["small_rune", "small_rune_2027"], ["big_rune", "big_rune_2027"]]:
		legacy.set_value("appearance", "robot", pair[0])
		legacy.save(legacy_path)
		var migrated = Settings.load_file(legacy_path)
		check(migrated.ok and migrated.settings.appearance.robot == pair[1], "legacy config maps to explicit season: " + pair[0])
		Settings.save_file(migrated.settings, legacy_path)
		var saved = ConfigFile.new()
		saved.load(legacy_path)
		check(saved.get_value("appearance", "robot") == pair[1], "saved configuration uses canonical season")
	legacy.set_value("appearance", "robot", "big_rune_2026")
	legacy.save(legacy_path)
	check(not Settings.load_file(legacy_path).ok, "unknown seasonal preset fails without borrowing another year")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path))

	if failures.is_empty():
		print("PASS: %d power-rune checks" % checks)
		quit(0)
	else:
		print("FAILED: %d / %d" % [failures.size(), checks])
		quit(1)
