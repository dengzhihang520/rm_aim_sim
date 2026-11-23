extends RefCounted

static var _geometry: Dictionary = {}
static var _templates: Dictionary = {}

static func specification(target: Dictionary) -> Dictionary:
	if _geometry.is_empty():
		_geometry = JSON.parse_string(FileAccess.get_file_as_string("res://assets/armor_cad/geometry.json"))
	# Width/height controls scale the closest nominal official module; defaults are 1:1.
	var model = "AM12" if absf(target.module_width - 0.235) < absf(target.module_width - 0.140) else "AM02"
	return _geometry[model]

static func model_name(target: Dictionary) -> String:
	return "AM12" if absf(target.module_width - 0.235) < absf(target.module_width - 0.140) else "AM02"

static func scale_for(target: Dictionary) -> Vector3:
	var spec = specification(target)
	return Vector3(target.module_width / (float(spec.nominal_mm[0]) * 0.001),
		target.module_height / (float(spec.nominal_mm[1]) * 0.001), 1.0)

static func bounds_boxes(target: Dictionary) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	var scale_value = scale_for(target)
	for part in specification(target).parts:
		var lo = Vector3(part.minimum[0], part.minimum[1], part.minimum[2]) * scale_value
		var hi = Vector3(part.maximum[0], part.maximum[1], part.maximum[2]) * scale_value
		parts.append({"size": hi-lo, "position": (hi+lo)*0.5, "light": part.light})
	return parts

static func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		_set_owner_recursive(child, owner_node)

static func instantiate(target: Dictionary) -> Node3D:
	var key = model_name(target)
	if not _templates.has(key):
		var document = GLTFDocument.new()
		var state = GLTFState.new()
		var error = document.append_from_file("res://assets/armor_cad/" + key + ".glb", state)
		if error != OK:
			push_error("Cannot load official armor CAD: " + key)
			return null
		var loaded = document.generate_scene(state)
		_set_owner_recursive(loaded, loaded)
		var scene = PackedScene.new()
		var packed = scene.pack(loaded)
		loaded.free()
		if packed != OK:
			push_error("Cannot instantiate official armor CAD: " + key)
			return null
		_templates[key] = scene
	var result = _templates[key].instantiate()
	result.name = "OfficialCADArmor"
	result.scale = scale_for(target)
	return result

static func _apply_materials(node: Node, lamp: Material, shell: Material, hardware: Material) -> void:
	if node is MeshInstance3D:
		var title = String(node.name)
		node.material_override = lamp if title.begins_with("Lightbar") else (hardware if title.begins_with("Hardware") else shell)
	for child in node.get_children():
		_apply_materials(child, lamp, shell, hardware)

static func build(parent: Node3D, target: Dictionary, lamp: Material, preset: Dictionary) -> void:
	var cad = instantiate(target)
	if cad == null:
		return
	parent.add_child(cad)
	var shell = StandardMaterial3D.new()
	shell.albedo_color = Color("0a0a0a")
	shell.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var hardware = StandardMaterial3D.new()
	hardware.albedo_color = Color("353739")
	hardware.metallic = 0.75
	hardware.roughness = 0.45
	_apply_materials(cad, lamp, shell, hardware)
	var original = Image.load_from_file(preset.sticker)
	if original == null:
		return
	var crop = original.get_region(Rect2i(preset.sticker_region))
	crop.convert(Image.FORMAT_RGBA8)
	# Only printed ink overlays the CAD plate; an opaque rectangular background would hide its relief.
	for y in range(crop.get_height()):
		for x in range(crop.get_width()):
			var color = crop.get_pixel(x,y)
			var opacity = clampf((maxf(color.r,maxf(color.g,color.b))-0.04)/0.96,0.0,1.0)
			crop.set_pixel(x,y,Color(1,1,1,opacity))
	var sticker = Sprite3D.new()
	sticker.name = "ArmorSticker"
	sticker.texture = ImageTexture.create_from_image(crop)
	sticker.pixel_size = minf(target.lightbar_spacing*0.72/crop.get_width(),target.module_height*0.8/crop.get_height())
	sticker.position.z = 0.0002
	sticker.double_sided = false
	parent.add_child(sticker)
