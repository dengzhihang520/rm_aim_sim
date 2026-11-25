extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Bridge = preload("res://scripts/bridge.gd")
var failures = 0
var checks = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func packet(sim: RefCounted, seq: int, fire: bool, requests: Array = []) -> Dictionary:
	return {"protocol": "rm_aim_sim/2", "type": "command", "session_id": sim.session_id,
		"seq": seq, "control": true, "fire": fire, "yaw": 0.0, "pitch": 0.0,
		"fire_events": requests}

func bridge_for(sim: RefCounted) -> RefCounted:
	var bridge = Bridge.new()
	bridge.model = sim
	bridge.enabled = true
	return bridge

func advance(sim: RefCounted, seconds: float) -> void:
	for _i in range(int(round(seconds * 1000))):
		sim.step(0.001)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var sim = Simulation.new()
	var bridge = bridge_for(sim)
	var event = {"seq": 0, "valid_until_unix_sec": Time.get_unix_time_from_system() + 0.2}
	# Only the latest false level remains when the renderer polls the overwritten mailbox.
	check(bridge.accept_command(packet(sim, 1, false, [event]), Time.get_ticks_usec()), "latest packet accepted")
	check(sim.fire_received_count == 1 and sim.stats.fired == 0, "event received before physics")
	check(bridge.accept_command(packet(sim, 2, false, [event]), Time.get_ticks_usec()), "unacknowledged event replay accepted")
	check(sim.fire_received_count == 1, "replayed event is deduplicated")
	advance(sim, 0.03)
	check(sim.stats.fired == 1 and sim.fire_consumed_count == 1, "short pulse becomes exactly one bullet")
	check(sim.last_fire_sequence == 0, "acknowledgement follows physical release")
	check(bridge.accept_command(packet(sim, 3, false, [event]), Time.get_ticks_usec()), "acknowledged replay accepted")
	advance(sim, 0.15)
	check(sim.stats.fired == 1, "replay cannot fire twice")

	sim = Simulation.new()
	bridge = bridge_for(sim)
	event = {"seq": 0, "valid_until_unix_sec": Time.get_unix_time_from_system() + 0.2}
	check(bridge.accept_command(packet(sim, 0, true, [event]), Time.get_ticks_usec()), "held fire accepted")
	advance(sim, 0.35)
	check(sim.stats.fired == 4 and sim.fire_consumed_count == 1, "held fire keeps original ten Hz rate without duplicate first shot")
	sim.stop()
	advance(sim, 0.2)
	check(sim.stats.fired == 4, "stop ends continuous fire")

	sim = Simulation.new()
	bridge = bridge_for(sim)
	event = {"seq": 0, "valid_until_unix_sec": Time.get_unix_time_from_system() - 1.0}
	check(bridge.accept_command(packet(sim, 0, false, [event]), Time.get_ticks_usec()), "expired event is accounted for")
	advance(sim, 0.03)
	check(sim.stats.fired == 0 and sim.fire_expired_count == 1 and sim.last_fire_sequence == 0, "expired request is acknowledged without firing")
	event = {"seq": 1, "valid_until_unix_sec": Time.get_unix_time_from_system() + 0.2}
	check(bridge.accept_command(packet(sim, 1, false, [event]), Time.get_ticks_usec()), "queued stop case accepted")
	sim.stop()
	advance(sim, 0.03)
	check(sim.stats.fired == 0 and sim.fire_cancelled_count == 1, "stop cancels queued request")
	event = {"seq": 2, "valid_until_unix_sec": Time.get_unix_time_from_system() + 0.2}
	check(bridge.accept_command(packet(sim, 2, false, [event]), Time.get_ticks_usec()), "delayed launch case accepted")
	advance(sim, 0.001)
	check(sim.pending.size() == 1 and sim.stats.fired == 0, "weapon delay remains effective")
	sim.stop()
	advance(sim, 0.03)
	check(sim.stats.fired == 0 and sim.fire_cancelled_count == 2, "stop cancels accepted delayed launch")
	bridge.reset_session()
	check(sim.last_fire_sequence == -1 and sim.last_received_fire_sequence == -1, "session reset clears event identity")
	var invalid = packet(sim, 4, false, [{"seq": 4.5, "valid_until_unix_sec": Time.get_unix_time_from_system()}])
	check(not bridge.accept_command(invalid, Time.get_ticks_usec()), "fractional event sequence rejected")
	invalid = packet(sim, 4, false, [{"seq": 5, "valid_until_unix_sec": Time.get_unix_time_from_system()}])
	check(not bridge.accept_command(invalid, Time.get_ticks_usec()), "future event sequence rejected")
	sim = Simulation.new()
	bridge = bridge_for(sim)
	event = {"seq": 0, "valid_until_unix_sec": Time.get_unix_time_from_system() + 0.2}
	check(bridge.accept_command(packet(sim, 0, false, [event]), Time.get_ticks_usec()), "cancellation barrier request accepted")
	advance(sim, 0.001)
	var resumed = packet(sim, 2, false)
	resumed["fire_cancel_seq"] = 1
	check(bridge.accept_command(resumed, Time.get_ticks_usec()), "stop barrier survives an overwritten control-off packet")
	advance(sim, 0.03)
	check(sim.stats.fired == 0 and sim.fire_cancelled_count == 1, "resume cannot replay a cancelled delayed request")
	print("FIRE EVENTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
