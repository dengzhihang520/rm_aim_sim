extends Node3D

const Outpost = preload("res://scripts/outpost.gd")
const Presets = preload("res://scripts/presets.gd")
var model: RefCounted
var world: Node3D
var guidance: MeshInstance3D
var indicator: MeshInstance3D


func build(simulation: RefCounted, view: Node3D) -> void:
	model = simulation
	world = view
	var body = world.material(Color("282c33"), 0.2)
	body.cull_mode = BaseMaterial3D.CULL_DISABLED
	for part in model.outpost_parts:
		var material = world.material(Color("75766b")) if part.bottom == 0.0 else body
		var vertices = Outpost.part_vertices(part)
		var surface = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for face in [[0, 2, 1], [0, 3, 2], [4, 5, 6], [4, 6, 7],
				[0, 1, 5], [0, 5, 4], [1, 2, 6], [1, 6, 5],
				[2, 3, 7], [2, 7, 6], [3, 0, 4], [3, 4, 7]]:
			for index in face:
				surface.add_vertex(world.to_engine(vertices[index]))
		surface.generate_normals()
		var node = MeshInstance3D.new()
		node.mesh = surface.commit()
		node.material_override = material
		add_child(node)
	var mesh = SphereMesh.new()
	mesh.radius = 0.0275
	mesh.height = 0.055
	guidance = MeshInstance3D.new()
	guidance.name = "DartGuidance"
	guidance.mesh = mesh
	guidance.position = world.to_engine(Vector3(-0.110, 0, model.settings.outpost.base_height + 1.446))
	guidance.material_override = world.material(Color("12ff34"), 0, 3)
	guidance.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	add_child(guidance)
	indicator = world.box(self, Vector3(0.014, 0.539, 0.006),
		world.to_engine(Vector3(-0.146, 0, model.settings.outpost.base_height + 0.8405)),
		world.material(Presets.team_color(model.settings.appearance.team), 0, 1))
	update_view()


func build_armor(plate: Node3D, lamp_material: StandardMaterial3D) -> void:
	var outline = Outpost.panel_outline()
	var triangles = Geometry2D.triangulate_polygon(outline)
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in [0.0, -0.020]:
		for index in triangles:
			var point = outline[index]
			surface.add_vertex(Vector3(point.x, point.y, z))
	for index in range(outline.size()):
		var a = outline[index]
		var b = outline[(index + 1) % outline.size()]
		for point in [Vector3(a.x, a.y, 0), Vector3(b.x, b.y, 0), Vector3(b.x, b.y, -0.020),
				Vector3(a.x, a.y, 0), Vector3(b.x, b.y, -0.020), Vector3(a.x, a.y, -0.020)]:
			surface.add_vertex(point)
	surface.generate_normals()
	var shell = MeshInstance3D.new()
	shell.mesh = surface.commit()
	var black = world.material(Color("111316"))
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.cull_mode = BaseMaterial3D.CULL_DISABLED
	shell.material_override = black
	plate.add_child(shell)
	var sticker = Sprite3D.new()
	sticker.name = "ArmorSticker"
	sticker.texture = preload("res://assets/outpost/mark.svg")
	sticker.pixel_size = 0.00014
	sticker.position.z = 0.0005
	sticker.double_sided = false
	plate.add_child(sticker)
	for side in [-1.0, 1.0]:
		world.box(plate, Vector3(0.005, Outpost.GEOMETRY.lightbar_length, 0.008),
			Vector3(side * Outpost.GEOMETRY.lightbar_spacing * 0.5, 0, 0.004), lamp_material)


func update_view() -> void:
	position = world.to_engine(model.outpost_base())
	var alive: bool = model.health > 0
	guidance.visible = alive
	indicator.visible = alive
	if alive:
		var ratio = clampf(float(model.health) / 1500.0, 0, 1)
		indicator.scale.y = ratio
		indicator.position.y = model.settings.outpost.base_height + 0.571 + 0.539 * ratio * 0.5
