extends RefCounted

# RMUC 2025 V2.1.0 section 5.6.2; RMUC 2027 V1.0.0 section 5.6.3.
const Presets = preload("res://scripts/presets.gd")
const RADIUS = 0.7
const TARGET_RADIUS = 0.154
const DETECTION_RADIUS = 0.150
const CENTER_DIAMETER = 0.106
const SMALL_SPEED = PI / 3.0
const RULES = {
	2025: {"paired_big": false, "blackout": 0.0, "unique_blades": true, "shrink": false},
	2027: {"paired_big": true, "blackout": 0.2, "unique_blades": false, "shrink": true},
}

var year = 2027
var rules: Dictionary = RULES[2027]
var time = 0.0
var big = false
var direction = 1.0
var angle = 0.0
var state = "ready"
var groups = 0
var hits = 0
var rings: Array[int] = []
var targets: Array[int] = []
var completed: Array[int] = []
var activation_count = 0
var target_end = INF
var second_end = INF
var blackout_end = INF
var a = 0.9125
var omega = 1.942
var epoch = 0.0
var rng = RandomNumberGenerator.new()
var last_outcome = ""
var benefit: Dictionary = {}


func reset(kind: String) -> void:
	var preset: Dictionary = Presets.ROBOTS[kind]
	year = preset.year
	rules = RULES[year]
	time = 0.0
	big = preset.size == "big"
	rng.randomize()
	direction = 1.0 if rng.randi_range(0, 1) == 0 else -1.0
	angle = 0.0
	state = "ready"
	groups = 0
	hits = 0
	rings.clear()
	targets.clear()
	completed.clear()
	activation_count = 0
	_clear_deadlines()
	benefit.clear()
	last_outcome = ""


func _clear_deadlines() -> void:
	target_end = INF
	second_end = INF
	blackout_end = INF


func speed(at: float) -> float:
	if big and state == "active":
		return direction * (a * sin(omega * (at - epoch)) + 2.09 - a)
	# Practice mode keeps the selected rune rotating, without a match schedule.
	return direction * SMALL_SPEED


func phase(at: float) -> float:
	var dt = at - time
	if big and state == "active":
		return angle + direction * (a / omega * (cos(omega * (time - epoch)) -
			cos(omega * (at - epoch))) + (2.09 - a) * dt)
	return angle + speed(time) * dt


func start(at: float) -> bool:
	if at < time:
		return false
	advance(at)
	_clear_deadlines()
	benefit.clear()
	last_outcome = ""
	# A button starts or restarts one practice attempt; match opportunities and cooldown do not apply.
	epoch = at
	a = rng.randf_range(0.780, 1.045)
	omega = rng.randf_range(1.884, 2.000)
	_restart(at, false)
	return true


func _restart(at: float, dark: bool) -> void:
	state = "active"
	groups = 0
	hits = 0
	rings.clear()
	completed.clear()
	targets.clear()
	target_end = INF
	second_end = INF
	blackout_end = at + rules.blackout if dark and rules.blackout > 0.0 else INF
	if blackout_end == INF:
		_choose(at)


func _choose(at: float) -> void:
	var candidates: Array[int] = [0, 1, 2, 3, 4]
	if rules.unique_blades:
		# In 2025 activation requires all five physical arms to be lit.
		for index in completed:
			candidates.erase(index)
	elif not big and not completed.is_empty():
		candidates.erase(completed.back())
	targets.clear()
	for _i in range(2 if big and rules.paired_big else 1):
		var index = rng.randi_range(0, candidates.size() - 1)
		targets.append(candidates[index])
		candidates.remove_at(index)
	target_end = at + 2.5
	second_end = INF
	blackout_end = INF


func _next_group(at: float) -> void:
	if groups >= 5:
		_finish(at)
		return
	targets.clear()
	target_end = INF
	second_end = INF
	if rules.blackout > 0.0:
		blackout_end = at + rules.blackout
	else:
		_choose(at)


func _finish(at: float) -> void:
	state = "activated"
	targets.clear()
	_clear_deadlines()
	if big:
		activation_count += 1
		var total = 0
		for ring in rings:
			total += ring
		if year == 2025:
			var attack = 150
			var defense = 25
			if total > 45:
				attack = 300 + (total - 45) * 40
				defense = 25 + (total - 45) * 5
			elif total > 40:
				attack = 300
			elif total > 35:
				attack = 200
			elif total > 25:
				attack = 160
			elif total > 15:
				attack = 155
			benefit = {"duration": 45.0, "total_ring": total, "attack_percent": attack,
				"defense_percent": defense, "experience": 500}
		else:
			var average = float(total) / rings.size()
			var duration = [30.0, 35.0, 40.0, 45.0, 50.0, 60.0][clampi(hits - 5, 0, 5)]
			benefit = {"duration": duration, "average_ring": average,
				"attack_percent": 150 if average <= 7 else (200 if average <= 9 else 300),
				"defense_percent": 25 if average <= 9 else 50,
				"cooling_multiplier": 1 if average <= 3 else (2 if average <= 8 else (3 if average <= 9 else 5)),
				"experience": 750}
	else:
		benefit = {"duration": 45.0, "defense_percent": 25,
			"structure_defense_percent": 75 if year == 2025 else 25,
			"extra_experience_percent": 100, "extra_experience_cap": 800 if year == 2025 else 1200}
	last_outcome = "activated"


func advance(at: float) -> void:
	if at < time:
		return
	while time < at:
		var next = at
		for deadline in [target_end, second_end, blackout_end]:
			next = minf(next, deadline)
		angle = phase(next)
		time = next
		if time >= second_end:
			_next_group(time)
		elif time >= target_end:
			last_outcome = "target_timeout"
			_restart(time, true)
		elif time >= blackout_end:
			_choose(time)


func detection_radius() -> float:
	if not rules.shrink or not big or activation_count == 0:
		return DETECTION_RADIUS
	return 0.105 if activation_count == 1 else 0.060


func receive_hit(index: int, radius: float, at: float) -> Dictionary:
	advance(at)
	var result = {"accepted": false, "blade": index, "ring": 0, "outcome": "inactive"}
	if radius > detection_radius() + 1e-9:
		result.outcome = "outside_detection"
		return result
	if state != "active" or time < blackout_end and blackout_end != INF:
		return result
	if index not in targets:
		last_outcome = "wrong_blade"
		result.outcome = last_outcome
		_restart(at, true)
		return result
	var radial_mm = roundf(radius * 1000.0)
	var ring = clampi(11 - ceili(radial_mm / 15.0), 1, 10)
	result.accepted = true
	result.ring = ring
	result.outcome = "accepted"
	hits += 1
	rings.append(ring)
	completed.append(index)
	targets.erase(index)
	if not big or not rules.paired_big:
		groups += 1
		_next_group(at)
	elif second_end == INF:
		groups += 1
		target_end = INF
		second_end = at + 1.0
	else:
		_next_group(at)
	if state == "activated":
		result.outcome = "activated"
	last_outcome = result.outcome
	return result


func snapshot() -> Dictionary:
	return {"year": year, "state": state, "mode": 3 if big else 2,
		"groups": groups, "hits": hits, "rings": rings.duplicate(), "targets": targets.duplicate(),
		"activation_count": activation_count,
		"detection_radius": detection_radius(), "angular_velocity": speed(time),
		"blackout": blackout_end != INF and time < blackout_end,
		"target_remaining": maxf(0.0, target_end - time) if target_end != INF else 0.0,
		"second_remaining": maxf(0.0, second_end - time) if second_end != INF else 0.0,
		"benefit": benefit.duplicate(), "outcome": last_outcome}
