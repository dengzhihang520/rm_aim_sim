extends RefCounted

# RMUC 2026 V2.2.0: Fig.4-34, Fig.5-16/17 and section5.5.1.
const SPEED = 0.8 * PI
const RAMP_TIME = 5.0
const ROTATION_LIMIT = 180.0
const REBUILD_LIMIT = 300.0
const INITIAL_PHASE = PI
const RADIUS = 0.275
const HEIGHTS = [1.114, 1.318, 1.216]
# 板面外法线向下15度，上沿向塔身外侧倾。
const TILT = -PI / 12.0
const HIT_INTERVAL = 0.050
const MIN_NORMAL_SPEED = 12.0
const GEOMETRY = {"module_width": 0.144, "module_height": 0.128,
	"lightbar_spacing": 0.130, "lightbar_length": 0.058}

var started_at = 0.0
var direction = 1.0
var stop_requested_at = -1.0
var stopped_at = -1.0
var stop_reason = ""
var ever_destroyed = false
var last_hits: Array[float] = []


func reset(at: float) -> void:
	started_at = at
	direction = 1.0 if randi() % 2 == 0 else -1.0
	stop_requested_at = -1.0
	stopped_at = -1.0
	stop_reason = ""
	ever_destroyed = false
	last_hits.assign([-INF, -INF, -INF])


func _free_phase(at: float) -> float:
	var t = clampf(at - started_at, 0.0, ROTATION_LIMIT)
	var ramp = minf(t, RAMP_TIME)
	return INITIAL_PHASE + direction * SPEED * (ramp * ramp / (2.0 * RAMP_TIME) + maxf(0, t - RAMP_TIME))


func _free_speed(at: float) -> float:
	if at - started_at >= ROTATION_LIMIT:
		return 0.0
	return direction * SPEED * clampf((at - started_at) / RAMP_TIME, 0.0, 1.0)


func phase(at: float) -> float:
	if stop_requested_at < 0.0 or at < stop_requested_at:
		return _free_phase(at)
	return _free_phase(minf(at, stopped_at))


func speed(at: float) -> float:
	if stop_requested_at < 0.0 or at < stop_requested_at:
		return _free_speed(at)
	return _free_speed(at) if at < stopped_at else 0.0


func request_stop(at: float, reason: String) -> void:
	if stop_requested_at >= 0.0:
		return
	stop_requested_at = at
	stop_reason = reason
	var distance = direction * (_free_phase(at) - INITIAL_PHASE)
	var turns = ceil(maxf(0.0, distance / TAU - 1e-10))
	var goal = turns * TAU
	# Keep the same ramp/cruise trajectory until the next initial layout; do not crawl at
	# a tiny startup speed when a stop is requested just after the round begins.
	var ramp_distance = SPEED * RAMP_TIME * 0.5
	var elapsed = sqrt(2.0 * goal * RAMP_TIME / SPEED) if goal <= ramp_distance else goal / SPEED + RAMP_TIME * 0.5
	stopped_at = maxf(at, started_at + elapsed)


func advance(at: float, destroyed: bool, base_open: bool) -> void:
	if at >= started_at + ROTATION_LIMIT:
		request_stop(started_at + ROTATION_LIMIT, "time_limit")
	if destroyed:
		ever_destroyed = true
		request_stop(at, "destroyed")
	if base_open:
		request_stop(at, "opponent_base_open")


func receive_hit(index: int, uv: Vector2, normal_speed: float, at: float) -> Dictionary:
	if normal_speed <= MIN_NORMAL_SPEED:
		return {"accepted": false, "reason": "normal_speed"}
	if at - last_hits[index] < HIT_INTERVAL - 1e-9:
		return {"accepted": false, "reason": "detection_interval"}
	last_hits[index] = at
	var critical = absf(uv.x) <= 0.005 + 1e-9 and absf(uv.y) <= 0.005 + 1e-9
	return {"accepted": true, "critical": critical, "damage": 30 if critical else 20}


func snapshot(at: float) -> Dictionary:
	return {"elapsed": maxf(0, at - started_at), "direction": direction,
		"angular_velocity": speed(at), "phase": phase(at), "ever_destroyed": ever_destroyed,
		"state": "rotating" if stop_requested_at < 0.0 else ("returning" if at < stopped_at else "stopped"),
		"stop_reason": stop_reason}


static func hit_outline() -> PackedVector2Array:
	# Fig.5-16:111mm reference width,2mm inset,5mm side recess and58mm middle band.
	return PackedVector2Array([Vector2(-0.0535, 0.047), Vector2(0.0535, 0.047),
		Vector2(0.0535, 0.031), Vector2(0.0485, 0.029), Vector2(0.0485, -0.029),
		Vector2(0.0535, -0.031), Vector2(0.0535, -0.047), Vector2(-0.0535, -0.047),
		Vector2(-0.0535, -0.031), Vector2(-0.0485, -0.029), Vector2(-0.0485, 0.029),
		Vector2(-0.0535, 0.031)])


static func panel_outline() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-0.064, 0.064), Vector2(0.064, 0.064),
		Vector2(0.072, 0.056), Vector2(0.072, -0.056), Vector2(0.064, -0.064),
		Vector2(-0.064, -0.064), Vector2(-0.072, -0.056), Vector2(-0.072, 0.056)])


static func clip_segment(p0: Vector3, p1: Vector3, planes: Array[Plane]) -> Dictionary:
	var enter = 0.0
	var leave = 1.0
	var normal = -(p1 - p0).normalized()
	for plane in planes:
		var distance = plane.distance_to(p0)
		var change = plane.normal.dot(p1 - p0)
		if absf(change) < 1e-12:
			if distance > 1e-8:
				return {}
			continue
		var t = -distance / change
		if change < 0.0:
			if t > enter:
				enter = t
				normal = plane.normal
		else:
			leave = minf(leave, t)
		if enter > leave + 1e-9:
			return {}
	return {"fraction": enter, "normal": normal} if enter <= 1.0 and leave >= 0.0 else {}


static func panel_collision(p0: Vector3, p1: Vector3) -> Dictionary:
	var planes: Array[Plane] = [Plane(Vector3(0, 0, 1), 0), Plane(Vector3(0, 0, -1), 0.020)]
	var points = panel_outline()
	for i in range(points.size()):
		var a = points[i]
		var edge = points[(i + 1) % points.size()] - a
		var n = Vector3(-edge.y, edge.x, 0).normalized()
		planes.append(Plane(n, n.dot(Vector3(a.x, a.y, 0))))
	return clip_segment(p0, p1, planes)


static func body_parts(base_height: float) -> Array[Dictionary]:
	# Dimensions not annotated in Fig.4-34 are simplified; these exact solids also block bullets.
	var parts: Array[Dictionary] = []
	if base_height > 0:
		parts.append({"bottom": 0.0, "top": base_height, "lower": Vector2(0.325, 0.325), "upper": Vector2(0.325, 0.325)})
	for part in [
		{"bottom": 0.0, "top": 0.100, "lower": Vector2(0.325, 0.325), "upper": Vector2(0.325, 0.325)},
		{"bottom": 0.100, "top": 0.560, "lower": Vector2(0.180, 0.180), "upper": Vector2(0.140, 0.140)},
		{"bottom": 0.560, "top": 1.410, "lower": Vector2(0.140, 0.140), "upper": Vector2(0.075, 0.075)},
		{"bottom": 1.410, "top": 1.578, "lower": Vector2(0.090, 0.090), "upper": Vector2(0.090, 0.090)}]:
		part.bottom += base_height
		part.top += base_height
		parts.append(part)
	return parts


static func part_planes(part: Dictionary) -> Array[Plane]:
	var slope: Vector2 = (part.upper - part.lower) / (part.top - part.bottom)
	var intercept: Vector2 = part.lower - slope * part.bottom
	return [Plane(Vector3(0, 0, -1), -part.bottom), Plane(Vector3(0, 0, 1), part.top),
		Plane(Vector3(1, 0, -slope.x), intercept.x), Plane(Vector3(-1, 0, -slope.x), intercept.x),
		Plane(Vector3(0, 1, -slope.y), intercept.y), Plane(Vector3(0, -1, -slope.y), intercept.y)]


static func part_vertices(part: Dictionary) -> PackedVector3Array:
	var result = PackedVector3Array()
	for layer in [[part.lower, part.bottom], [part.upper, part.top]]:
		for signs in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			result.append(Vector3(signs.x * layer[0].x, signs.y * layer[0].y, layer[1]))
	return result
