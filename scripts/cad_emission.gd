extends RefCounted

var viewport: SubViewport
var camera: Camera3D
var proxies: Array[Node3D] = []
var source_plates: Array[Node3D] = []
var lights: Array[StandardMaterial3D] = []
var black: StandardMaterial3D
var bullets: Dictionary = {}
var bullet_mesh: SphereMesh
var gun: Node3D

func _material(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material

func setup(world: Node3D) -> void:
	black = _material(Color.BLACK)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.size = world.raw_sensor_viewport.size
	world.add_child(viewport)
	camera = Camera3D.new()
	camera.near = world.sensor_camera.near
	camera.far = world.sensor_camera.far
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	camera.environment = environment
	viewport.add_child(camera)
	camera.current = true
	# Reuse the visible world's solid ground and gimbal supports as occluders.
	for child in world.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			var occluder = child.duplicate()
			occluder.material_override = black
			viewport.add_child(occluder)
	bullet_mesh = SphereMesh.new()
	bullet_mesh.radius = 0.0084
	bullet_mesh.height = 0.0168
	bullet_mesh.radial_segments = 8
	bullet_mesh.rings = 4
	gun = world.gun.duplicate()
	_override(gun,black)
	viewport.add_child(gun)

func _override(node: Node, material: Material) -> void:
	if node is Sprite3D:
		node.queue_free()
		return
	if node is MeshInstance3D:
		node.material_override = material
	for child in node.get_children():
		_override(child,material)

func _mask_materials(node: Node, lamp: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = lamp if String(node.name).begins_with("Lightbar") else black
	for child in node.get_children():
		_mask_materials(child,lamp)

func rebuild(plates: Array[Node3D]) -> void:
	for proxy in proxies:
		proxy.free()
	proxies.clear()
	lights.clear()
	source_plates = plates.duplicate()
	for plate in plates:
		var source = plate.get_node_or_null("OfficialCADArmor")
		if source == null:
			continue
		var holder = Node3D.new()
		var copy = source.duplicate()
		holder.add_child(copy)
		var lamp = _material(Color.WHITE)
		_mask_materials(copy,lamp)
		viewport.add_child(holder)
		proxies.append(holder)
		lights.append(lamp)

func update(world: Node3D) -> void:
	viewport.size = world.raw_sensor_viewport.size
	camera.fov = world.sensor_camera.fov
	camera.global_transform = world.sensor_camera.global_transform
	gun.global_transform = world.gun.global_transform
	for index in range(proxies.size()):
		proxies[index].global_transform = source_plates[index].global_transform
		lights[index].albedo_color = Color.WHITE if world.model.armor_light_on(index) else Color.BLACK
	var alive: Dictionary = {}
	for bullet in world.model.projectiles:
		alive[bullet.id] = true
		if not bullets.has(bullet.id):
			var node = MeshInstance3D.new()
			node.mesh = bullet_mesh
			node.material_override = black
			viewport.add_child(node)
			bullets[bullet.id] = node
		var position: Vector3 = world.model.bullet_position(bullet,world.model.time)
		bullets[bullet.id].position = Vector3(-position.y,position.z,-position.x)
	for key in bullets.keys():
		if not alive.has(key):
			bullets[key].queue_free()
			bullets.erase(key)
