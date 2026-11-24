extends SceneTree

const Settings = preload("res://scripts/settings.gd")
const Simulation = preload("res://scripts/simulation.gd")
const Outpost = preload("res://scripts/outpost.gd")
const Presets = preload("res://scripts/presets.gd")
var checks = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)


func close_to(a: float, b: float, message: String, tolerance: float = 1e-6) -> void:
	check(absf(a - b) < tolerance, message + " actual=" + str(a) + " expected=" + str(b))


func settings() -> Dictionary:
	var s = Settings.defaults()
	s.appearance.robot = "outpost_2026"
	s.outpost.opponent_base_open = true
	s.weapon.gravity = 0.0
	s.weapon.delay = 0.0
	return s


func shoot(sim: RefCounted, point: Vector3) -> void:
	var delta: Vector3 = point - sim.settings.gimbal.origin
	var command = {"control": true, "fire": false, "yaw": atan2(delta.y, delta.x),
		"pitch": -atan2(delta.z, Vector2(delta.x, delta.y).length())}
	sim.set_command(command)
	sim.step(1.0)
	command.fire = true
	sim.set_command(command)
	sim.step(0.001)
	command.fire = false
	sim.set_command(command)
	sim.step(0.4)


func test_motion() -> void:
	var state = Outpost.new()
	state.reset(7.0)
	var sign_value: float = state.direction
	check(sign_value in [-1.0, 1.0], "rotation direction is selected once per round")
	close_to(state.speed(7), 0, "start from rest")
	close_to(state.speed(9.5), sign_value * Outpost.SPEED * 0.5, "linear acceleration halfway")
	close_to(state.speed(12), sign_value * Outpost.SPEED, "reach0.8pi within5s")
	close_to(state.speed(100), sign_value * Outpost.SPEED, "cruise speed remains fixed")
	close_to(state.phase(12) - state.phase(7), sign_value * Outpost.SPEED * 2.5, "ramp angle is integrated")
	state.advance(187, false, false)
	close_to(state.speed(188), 0, "three-minute limit stops rotation")
	close_to(wrapf(state.phase(188) - Outpost.INITIAL_PHASE, -PI, PI), 0, "time limit retains initial layout")
	check(state.stop_reason == "time_limit", "time limit reason is recorded")
	state.reset(0)
	state.advance(7.2, true, false)
	check(state.ever_destroyed and state.stop_reason == "destroyed", "first death latches the stop")
	var end: float = state.stopped_at
	check(end - 7.2 < 2.501, "return to initial position completes within one turn at cruise speed")
	close_to(wrapf(state.phase(end + 1) - PI, -PI, PI), 0, "death returns to the initial layout")
	state.advance(end + 1, false, false)
	close_to(state.speed(end + 10), 0, "restoring health cannot restart rotation")
	state.reset(10)
	state.advance(11, false, true)
	state.advance(state.stopped_at + 1, false, false)
	close_to(state.speed(state.stopped_at + 2), 0, "closing the base-open training flag cannot undo a latched stop")

	for at in [0.0, 0.000001, 0.01, 1.0, 4.99, 5.0, 5.01, 179.99]:
		state.reset(0)
		state.advance(at, false, true)
		check(state.stopped_at - at <= 5.0 + 1e-6, "startup stop completes on the same trajectory within one ramp/turn")
		close_to(wrapf(state.phase(state.stopped_at + 1) - PI, -PI, PI), 0,
			"stopping from any ramp/cruise phase reaches the initial layout")


func test_damage_gate() -> void:
	var state = Outpost.new()
	state.reset(0)
	check(not state.receive_hit(0, Vector2.ZERO, 12, 0).accepted, "normal speed must be strictly above12m/s")
	var hit: Dictionary = state.receive_hit(0, Vector2.ZERO, 12.001, 0)
	check(hit.accepted and hit.damage == 30 and hit.critical, "10mm center gains150percent damage")
	check(not state.receive_hit(0, Vector2.ZERO, 23, 0.049).accepted, "same module rejects hits inside50ms")
	hit = state.receive_hit(0, Vector2(0.02, 0), 23, 0.050)
	check(hit.accepted and hit.damage == 20 and not hit.critical, "ordinary hit at50ms is20HP")
	check(state.receive_hit(1, Vector2.ZERO, 23, 0.050).accepted, "module detection intervals are independent")
	check(state.receive_hit(2, Vector2(0.005, 0.005), 23, 0.050).critical, "critical boundary is a square")
	check(not state.receive_hit(2, Vector2(0.0051, 0), 23, 0.100).critical, "outside the critical square gets ordinary damage")
	for point in [Vector2.ZERO, Vector2(0.048, 0), Vector2(0.053, 0.040)]:
		check(Geometry2D.is_point_in_polygon(point, Outpost.hit_outline()), "effective polygon contains marked active area")
	for point in [Vector2(0.050, 0), Vector2(0, 0.050), Vector2(0.060, 0.040)]:
		check(not Geometry2D.is_point_in_polygon(point, Outpost.hit_outline()), "frame and side recess are not active armor")
	check(Outpost.panel_collision(Vector3(0.060, 0, 0.01), Vector3(0.060, 0, -0.03)).has("fraction"), "inactive frame still physically blocks a bullet")


func test_scene_and_physics() -> void:
	var loaded = Settings.load_file("res://configs/outpost_2026.cfg")
	check(loaded.ok, "new independent scenario validates")
	var sim = Simulation.new(settings())
	check(sim.armor_count() == 3 and sim.health == 1500, "outpost has three modules and1500HP")
	var original_K: Array = sim.camera_observation().K.duplicate()
	for i in range(3):
		var plate: Dictionary = sim.armor_pose(i, 0)
		close_to(plate.center.z, 0.3 + Outpost.HEIGHTS[i], "plate height follows Fig.4-34")
		close_to(Vector2(plate.center.x - sim.outpost_base().x, plate.center.y - sim.outpost_base().y).length(), 0.275, "plate trajectory radius")
		close_to(plate.normal.z, -sin(PI / 12), "middle plate outward normal points15degrees down")
		var radial: Vector3 = plate.center - sim.outpost_base()
		radial.z = 0.0
		check(plate.up.dot(radial.normalized()) > 0.0, "middle plate top leans away from the tower")
		close_to(plate.normal.dot(plate.up), 0, "plate normal stays perpendicular to its up axis")
	check(sim.snapshot().truth.armors.size() == 3 and sim.snapshot().mode == 1, "normal IPC publishes three armors in auto-aim mode")
	var s: Dictionary = sim.settings.duplicate(true)
	s.target.translate = true
	s.target.rotate = true
	s.target.omega = 19.0
	sim.apply_settings(s)
	var before: Dictionary = sim.target_pose(sim.time)
	sim.step(0.2)
	check(sim.target_pose(sim.time) == before, "vehicle motion settings cannot move or spin an outpost")
	check(sim.camera_observation().K == original_K, "outpost controls retain camera calibration")
	var pose: Dictionary = sim.armor_pose(0, sim.time)
	shoot(sim, pose.center)
	check(sim.stats.fired == 1 and sim.stats.hit == 1 and sim.stats.damage == 30, "normal command, muzzle and ballistic collision register a critical hit")
	shoot(sim, pose.center + pose.tangent * 0.020)
	check(sim.stats.hit == 2 and sim.stats.damage == 50, "off-center physical hit deducts20HP")
	var damage_before: int = sim.stats.damage
	shoot(sim, pose.center + pose.tangent * 0.060)
	check(sim.stats.damage == damage_before and sim.stats.body > 0, "frame impact cannot deduct armor health")
	shoot(sim, sim.outpost_base() + Vector3(0, 0, 1.0))
	check(sim.stats.damage == damage_before, "tower structure physically stops a shot without armor damage")
	check(not sim.has_line_of_sight(sim.settings.gimbal.origin, sim.outpost_base() + Vector3(0.3, 0, 1.0)), "tower occludes points behind it")
	check(sim.metrics().fired == sim.metrics().resolved + sim.metrics().in_flight, "physical shot accounting closes")
	var high = Simulation.new(settings())
	var config: Dictionary = high.settings.duplicate(true)
	config.outpost.base_height = 1.20
	config.outpost.forward = 8.0
	config.outpost.lateral = 0.50
	high.apply_settings(config)
	check(Settings.validate(high.settings).is_empty(), "building height is independent of the vehicle400mm lower-edge rule")
	close_to(high.armor_pose(0, high.time).center.z, 2.314, "live base-height edits move physical modules")
	var path = "user://outpost_roundtrip.cfg"
	check(Settings.save_file(high.settings, path) == OK, "outpost options save")
	var readback = Settings.load_file(path)
	check(readback.ok and readback.settings.outpost == high.settings.outpost, "outpost options survive read-write-read")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_rebuild_and_switch() -> void:
	var sim = Simulation.new(settings())
	var point: Vector3 = sim.armor_pose(0, 0).center
	var delta: Vector3 = point - sim.settings.gimbal.origin
	sim.set_command({"control": true, "fire": false, "yaw": 0.0,
		"pitch": -atan2(delta.z, Vector2(delta.x, delta.y).length())})
	sim.step(1.0)
	sim.set_command({"control": true, "fire": true, "yaw": 0.0,
		"pitch": -atan2(delta.z, Vector2(delta.x, delta.y).length())})
	sim.step(8.0)
	sim.stop()
	sim.step(0.4)
	check(sim.health == 0 and sim.stats.kills == 1, "real repeated fire destroys1500HP outpost once")
	check(sim.outpost.ever_destroyed and not sim.armor_light_on(0), "first destruction latches stop and extinguishes armor")
	var phase: float = sim.outpost.phase(sim.time)
	var total: Dictionary = sim.stats.duplicate()
	check(sim.rebuild_outpost() and sim.health == 750 and sim.max_health == 1500, "training rebuild restores750HP")
	check(sim.events[-1].type == "outpost_rebuilt" and sim.events[-1].id == sim.next_health_event_id - 1
		and sim.events[-1].max_health == 1500, "rebuild event follows normal deduplication and health fields")
	sim.step(0.1)
	close_to(sim.outpost.speed(sim.time), 0, "rebuilt outpost remains stopped")
	close_to(sim.outpost.phase(sim.time), phase, "rebuild retains the stopped layout")
	check(sim.armor_light_on(0) and sim.stats == total, "rebuild restores lights without resetting statistics")
	check(not sim.rebuild_outpost(), "living outpost cannot be rebuilt repeatedly")
	var changed: Dictionary = sim.settings.duplicate(true)
	changed.appearance.team = "red"
	var direction: float = sim.outpost.direction
	sim.apply_settings(changed)
	check(sim.outpost.direction == direction, "red and blue share the same round direction")
	var key: Array = sim.camera_observation().K.duplicate()
	changed.appearance.robot = "big_rune_2025"
	sim.apply_settings(changed)
	check(sim.armor_count() == 0 and sim.snapshot().mode == 3, "outpost switches to rune through the normal mode")
	changed.appearance.robot = "infantry_3_2026"
	sim.apply_settings(changed)
	check(sim.armor_count() == 4 and sim.health == 350, "returning to infantry restores four modules and vehicle health")
	check(sim.camera_observation().K == key and sim.stats == total, "category changes retain intrinsics and accumulated results")


func test_time_limit_and_validation() -> void:
	var sim = Simulation.new(settings())
	var pose: Dictionary = sim.armor_pose(0, 0)
	var d: Vector3 = pose.center - sim.settings.gimbal.origin
	sim.set_command({"control": true, "fire": true, "yaw": 0.0,
		"pitch": -atan2(d.z, Vector2(d.x, d.y).length())})
	sim.step(9.0)
	sim.stop()
	sim.step(0.5)
	check(sim.health == 0, "outpost destroyed before the rebuild deadline")
	sim.step(301.0 - sim.time)
	check(not sim.rebuild_outpost() and sim.health == 0, "five-minute rule rejects late training rebuilds")
	for values in [["forward", 0.9], ["forward", 20.1], ["lateral", 15.1], ["base_height", -0.01], ["base_height", 2.01]]:
		var s = settings()
		s.outpost[values[0]] = values[1]
		check(not Settings.validate(s).is_empty(), "invalid outpost placement rejected: " + str(values))
	var invalid = settings()
	invalid.outpost.opponent_base_open = 1
	check(not Settings.validate(invalid).is_empty(), "base-open control must be boolean")


func run() -> void:
	test_motion()
	test_damage_gate()
	test_scene_and_physics()
	test_rebuild_and_switch()
	test_time_limit_and_validation()
	if failures.is_empty():
		print("PASS: %d outpost checks" % checks)
	else:
		print("FAILED: %d / %d outpost checks" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
