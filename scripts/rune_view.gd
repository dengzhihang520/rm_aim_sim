extends Node3D

const World = preload("res://scripts/world_view.gd")
const Rune = preload("res://scripts/power_rune.gd")
const Presets = preload("res://scripts/presets.gd")
var model: RefCounted
var faces: Array[Node3D] = []
var frames: Array[Node3D] = []
var marks: Array[Node3D] = []
var bars: Array[MeshInstance3D] = []
var arrows: Array[Node3D] = []
var score_marks: Array = []
var support_legs: Array[MeshInstance3D] = []
var base: MeshInstance3D
var rotor: Node3D


func build(simulation: RefCounted) -> void:
	model = simulation
	var dark = World.material(Color("111318"))
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	rotor = Node3D.new()
	add_child(rotor)
	for i in range(5):
		var face = Node3D.new()
		rotor.add_child(face)
		faces.append(face)
		var color = World.material(Presets.team_color(model.settings.appearance.team), 0, 1.5)
		color.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		color.cull_mode = BaseMaterial3D.CULL_DISABLED
		var frame = Node3D.new()
		face.add_child(frame)
		frames.append(frame)
		# Figure 4-32: 372 x 382 mm board, 308 mm disc, 700 mm pitch radius.
		var outline = PackedVector2Array([Vector2(-0.186, 0.861), Vector2(-0.05, 0.891),
			Vector2(0.05, 0.891), Vector2(0.186, 0.861), Vector2(0.186, 0.539),
			Vector2(0.05, 0.509), Vector2(-0.05, 0.509), Vector2(-0.186, 0.539)])
		_polygon(face, outline, dark, 0)
		for j in range(outline.size()):
			_line(frame, outline[j], outline[(j + 1) % outline.size()], 0.022, color, 0.003)
		for side in [-1.0, 1.0]:
			var path = [Vector2(side * 0.17, 0.51), Vector2(side * 0.18, 0.326), Vector2(side * 0.068, 0.18)]
			for j in range(2):
				_line(face, path[j], path[j + 1], 0.040, dark, 0)
				_line(frame, path[j], path[j + 1], 0.024, color, 0.003)
		_disc(face, Vector2(0, 0.7), Rune.TARGET_RADIUS, dark, 0.006)
		var marking = Node3D.new()
		face.add_child(marking)
		marks.append(marking)
		# Figure 5-21: three 20 mm light bands; 300 mm is the target boundary, not a light-band edge.
		for radii in [Vector2(0.015, 0.035), Vector2(0.055, 0.075), Vector2(0.115, 0.135)]:
			_ring(marking, Vector2(0, 0.7), radii.x, radii.y, color, 0.009)
		var inner_half_width = 0.0175 - 0.100 * tan(deg_to_rad(7.0))
		for j in range(4):
			var axis = Vector2(sin(j * PI / 2.0), cos(j * PI / 2.0))
			var tangent = Vector2(axis.y, -axis.x)
			var origin = Vector2(0, 0.7)
			_polygon(marking, PackedVector2Array([origin + axis * 0.050 - tangent * inner_half_width,
				origin + axis * 0.150 - tangent * 0.0175, origin + axis * 0.150 + tangent * 0.0175,
				origin + axis * 0.050 + tangent * inner_half_width]), color, 0.009)
		var scored: Array[Node3D] = []
		for ring in range(1, 11):
			var indicator = Node3D.new()
			face.add_child(indicator)
			var radius = (11 - ring) * 0.015
			_ring(indicator, Vector2(0, 0.7), radius - 0.006, radius, color, 0.010)
			scored.append(indicator)
		score_marks.append(scored)
		var bar = World.box(face, Vector3(0.060, 0.330, 0.008), Vector3(0, 0.345, 0.003), color)
		_add_core_box(bar, Vector3(0.024, 0.324, 0.002), color)
		_line_glare(bar, Vector2(0, -0.165), Vector2(0, 0.165), 0.060, color, 0.007)
		bars.append(bar)
		var flow = Node3D.new()
		face.add_child(flow)
		arrows.append(flow)
		# The recorded light train contains about eight closely spaced chevrons on the330mm axis.
		for j in range(8):
			var chevron = Node3D.new()
			flow.add_child(chevron)
			_polygon(chevron, PackedVector2Array([Vector2(-0.03, -0.02), Vector2(0, 0.0),
				Vector2(0.03, -0.02), Vector2(0.03, -0.005), Vector2(0, 0.015), Vector2(-0.03, -0.005)]), color, 0.010)
			_line_glare(chevron, Vector2(-0.03, -0.0125), Vector2(0, 0.0075), 0.012, color, 0.012)
			_line_glare(chevron, Vector2(0, 0.0075), Vector2(0.03, -0.0125), 0.012, color, 0.012)
		# Opposite face shares the axle, but has its own untriggered team indication.
		var back = Node3D.new()
		face.add_child(back)
		back.position.z = -0.07
		back.rotation.y = PI
		_polygon(back, outline, dark, 0)
		_disc(back, Vector2(0, 0.7), Rune.TARGET_RADIUS, dark, 0.006)
	_disc(self, Vector2.ZERO, 0.178, dark, 0.017)
	_disc(self, Vector2.ZERO, Rune.CENTER_DIAMETER * 0.5, dark, 0.025)
	World.box(self, Vector3(2.50, 0.10, 0.12), Vector3(0, 0, -0.12), dark)
	for side in [-1.0, 1.0]:
		support_legs.append(World.box(self, Vector3(0.09, 1, 0.12), Vector3(side * 1.12, -0.5, -0.12), dark))
	base = World.box(self, Vector3(2.8, 0.30, 0.75), Vector3(0, -1, -0.12), dark)
	var logo = Sprite3D.new()
	logo.texture = load("res://assets/rune/center_r.svg")
	logo.pixel_size = 0.080 / logo.texture.get_width()
	logo.modulate = Presets.team_color(model.settings.appearance.team).lerp(Color.WHITE, 0.55)
	logo.double_sided = false
	logo.position.z = 0.027
	add_child(logo)
	update_view()


func update_view() -> void:
	var basis = model.rune_basis()
	transform = Transform3D(Basis(World.to_engine(basis.x), World.to_engine(basis.y), World.to_engine(basis.z)),
		World.to_engine(model.rune_center()))
	for leg in support_legs:
		leg.scale.y = maxf(0.01, model.settings.rune.height - 0.30)
		leg.position.y = -(model.settings.rune.height - 0.30) * 0.5
	base.position.y = -model.settings.rune.height + 0.15
	var dark = model.rune.blackout_end != INF and model.time < model.rune.blackout_end
	var paired: bool = model.rune.big and model.rune.rules.paired_big
	var activated: bool = model.rune.state == "activated"
	var progress: int = model.rune.groups
	# The new fraction appears on entry to the next group, not while its second target is pending.
	if paired and model.rune.second_end != INF:
		progress -= 1
	for i in range(5):
		faces[i].rotation.z = -model.rune.phase(model.time) - i * TAU / 5.0
		var selected: bool = i in model.rune.targets and not dark
		var completed: bool = i in model.rune.completed and not dark
		# The paired rune's physical arms are reused. History is for scoring, not permanent full-arm lights.
		var full: bool = activated or not paired and completed and not selected
		frames[i].visible = not dark and full
		marks[i].visible = selected
		arrows[i].visible = selected
		for j in range(arrows[i].get_child_count()):
			var chevron = arrows[i].get_child(j)
			chevron.position.y = 0.20 + fposmod(model.time * 0.24 + j * 0.330 / 8.0, 0.330)
			chevron.visible = chevron.position.y + 0.015 <= 0.51
		bars[i].visible = not dark and (progress > 0 if paired else full)
		bars[i].scale.y = maxf(0.001, progress / 5.0) if paired else 1.0
		bars[i].position.y = 0.18 + 0.165 * bars[i].scale.y
		var hit_index: int = model.rune.completed.rfind(i)
		var scored_ring: int = model.rune.rings[hit_index] if hit_index >= 0 else 0
		var show_score: bool = completed and not selected
		if paired and not activated:
			show_score = not dark and model.rune.second_end != INF and not model.rune.completed.is_empty() and model.rune.completed.back() == i
		for j in range(10):
			var ring = j + 1
			var lit_ring: bool = ring == scored_ring or scored_ring == 10 and ring in [1, 3, 5, 7, 9, 10]
			if not model.rune.big:
				lit_ring = ring == 1
			score_marks[i][j].visible = show_score and lit_ring


# Compatibility rendering clips HDR before the sensor exposure pass. A narrow luminous core
# retains the near-white LED filament separately from the surrounding team-colored light.
static func _core_material(mat: StandardMaterial3D) -> StandardMaterial3D:
	var core = World.material(mat.albedo_color.lerp(Color.WHITE, 0.85), 0.0, 12.0)
	core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core.cull_mode = BaseMaterial3D.CULL_DISABLED
	return core


static func _add_core_box(node: MeshInstance3D, size: Vector3, mat: StandardMaterial3D) -> void:
	World.box(node, size, Vector3(0, 0, 0.005), _core_material(mat))


static func _polygon(parent: Node3D, outline: PackedVector2Array, mat: Material, z: float) -> void:
	_polygon_mesh(parent, outline, mat, z)
	if mat is StandardMaterial3D and mat.emission_enabled:
		for core in Geometry2D.offset_polygon(outline, -0.004):
			_polygon_mesh(parent, core, _core_material(mat), z + 0.001)


static func _polygon_mesh(parent: Node3D, outline: PackedVector2Array, mat: Material, z: float) -> void:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices = Geometry2D.triangulate_polygon(outline)
	for index in indices:
		surface.add_vertex(Vector3(outline[index].x, outline[index].y, z))
	surface.generate_normals()
	var node = MeshInstance3D.new()
	node.mesh = surface.commit()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = mat
	# Both the front board and the structural back are visible, while lights use their own face.
	parent.add_child(node)


static func _line(parent: Node3D, start: Vector2, end: Vector2, width: float, mat: Material, z: float) -> MeshInstance3D:
	var node = World.box(parent, Vector3(width, start.distance_to(end), 0.006), Vector3((start.x + end.x) * 0.5, (start.y + end.y) * 0.5, z), mat)
	node.rotation.z = -atan2(end.x - start.x, end.y - start.y)
	if mat is StandardMaterial3D and mat.emission_enabled:
		_add_core_box(node, Vector3(width * 0.4, start.distance_to(end) * 0.98, 0.002), mat)
		_line_glare(parent, start, end, width, mat, z + 0.005)
	return node


static func _disc(parent: Node3D, center: Vector2, radius: float, mat: Material, z: float) -> void:
	var points = PackedVector2Array()
	for i in range(96):
		points.append(center + Vector2(cos(i * TAU / 96), sin(i * TAU / 96)) * radius)
	_polygon(parent, points, mat, z)


static func _ring(parent: Node3D, center: Vector2, inner: float, outer: float, mat: Material, z: float) -> void:
	_ring_mesh(parent, center, inner, outer, mat, z)
	if mat is StandardMaterial3D and mat.emission_enabled:
		var middle = (inner + outer) * 0.5
		var half_width = (outer - inner) * 0.2
		_ring_mesh(parent, center, middle - half_width, middle + half_width, _core_material(mat), z + 0.001)
		_ring_glare(parent, center, inner, outer, mat, z + 0.002)


static func _line_glare(parent: Node3D, start: Vector2, end: Vector2, width: float, mat: StandardMaterial3D, z: float) -> void:
	var node = MeshInstance3D.new()
	var mesh = QuadMesh.new()
	var length = start.distance_to(end)
	mesh.size = Vector2(width + 0.14, length + 0.14)
	var glow = ShaderMaterial.new()
	glow.shader = preload("res://shaders/lamp_glow.gdshader")
	glow.set_shader_parameter("team_color", mat.albedo_color)
	glow.set_shader_parameter("core_color", mat.albedo_color.lerp(Color.WHITE, 0.85))
	glow.set_shader_parameter("lamp_width", width)
	glow.set_shader_parameter("lamp_length", length)
	glow.set_shader_parameter("plane_size", mesh.size)
	node.mesh = mesh
	node.material_override = glow
	node.position = Vector3((start.x + end.x) * 0.5, (start.y + end.y) * 0.5, z)
	node.rotation.z = -atan2(end.x - start.x, end.y - start.y)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)


static func _ring_glare(parent: Node3D, center: Vector2, inner: float, outer: float, mat: StandardMaterial3D, z: float) -> void:
	var node = MeshInstance3D.new()
	var mesh = QuadMesh.new()
	mesh.size = Vector2.ONE * (outer + 0.08) * 2.0
	var glow = ShaderMaterial.new()
	glow.shader = preload("res://shaders/rune_ring_glow.gdshader")
	glow.set_shader_parameter("team_color", mat.albedo_color)
	glow.set_shader_parameter("core_color", mat.albedo_color.lerp(Color.WHITE, 0.85))
	glow.set_shader_parameter("inner_radius", inner)
	glow.set_shader_parameter("outer_radius", outer)
	glow.set_shader_parameter("plane_size", mesh.size)
	node.mesh = mesh
	node.material_override = glow
	node.position = Vector3(center.x, center.y, z)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)


static func _ring_mesh(parent: Node3D, center: Vector2, inner: float, outer: float, mat: Material, z: float) -> void:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(96):
		var a = Vector2(cos(i * TAU / 96), sin(i * TAU / 96))
		var b = Vector2(cos((i + 1) * TAU / 96), sin((i + 1) * TAU / 96))
		for p in [center + a * inner, center + a * outer, center + b * outer,
			center + a * inner, center + b * outer, center + b * inner]:
			surface.add_vertex(Vector3(p.x, p.y, z))
	surface.generate_normals()
	var node = MeshInstance3D.new()
	node.mesh = surface.commit()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = mat
	parent.add_child(node)
