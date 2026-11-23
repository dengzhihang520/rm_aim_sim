extends SceneTree

var failures: Array[String] = []
var checks = 0
var main: Node


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)


func select_target(name: String) -> void:
	for i in range(main.robot_select.item_count):
		if main.robot_select.get_item_metadata(i) == name:
			main.robot_select.select(i)
			main.robot_select.item_selected.emit(i)
			return
	check(false, "target exists: " + name)


func capture(name: String) -> Image:
	main.world.update_world()
	await RenderingServer.frame_post_draw
	var path = "res://.tools/verification/rune2027/" + name
	main.get_viewport().get_texture().get_image().save_png(path + ".png")
	var sensor = main.world.sensor_viewport.get_texture().get_image()
	sensor.save_png(path + "-sensor.png")
	return sensor


func count_visible(nodes: Array) -> int:
	var count = 0
	for node in nodes:
		if node.visible:
			count += 1
	return count


func step_rune(duration: float) -> void:
	main.model.paused = false
	main.model.step(duration)
	main.model.paused = true


func test_lights() -> void:
	for kind in ["small_rune_2025", "big_rune_2025", "small_rune_2027", "big_rune_2027"]:
		select_target(kind)
		var rune = main.model.rune
		var view = main.world.rune_view
		var paired: bool = rune.big and rune.rules.paired_big
		main.world.update_world()
		check(count_visible(view.frames) == 0 and count_visible(view.arrows) == 0 and count_visible(view.bars) == 0 and count_visible(view.marks) == 0, "ready rune has no target or arm lights: " + kind)
		main.model.paused = false
		main.rune_start.pressed.emit()
		main.model.paused = true
		main.world.update_world()
		check(count_visible(view.frames) == 0 and count_visible(view.bars) == 0, "selecting targets does not illuminate completed outlines or solid bars: " + kind)
		check(count_visible(view.marks) == (2 if paired else 1) and count_visible(view.arrows) == (2 if paired else 1), "pending targets show patterns and flowing arrows: " + kind)
		var sensor = await capture("lights-" + kind + "-pending")
		var cores = 0
		for y in range(0, sensor.get_height(), 3):
			for x in range(0, sensor.get_width(), 3):
				var color = sensor.get_pixel(x, y)
				if color.r > 0.4 and color.g > 0.4 and color.b > 0.5:
					cores += 1
		check(cores > 0, "rune camera pixels contain near-white LED cores instead of only dark saturated blue: " + kind)
		var gain: float = main.model.settings.camera.brightness_gain
		main.model.settings.camera.brightness_gain = 0.0
		main.world.update_world()
		await RenderingServer.frame_post_draw
		var closed = main.world.sensor_viewport.get_texture().get_image()
		var lit_pixels = 0
		for y in range(0, closed.get_height(), 5):
			for x in range(0, closed.get_width(), 5):
				var color = closed.get_pixel(x, y)
				if color.r > 0 or color.g > 0 or color.b > 0:
					lit_pixels += 1
		check(lit_pixels == 0, "LED cores still obey zero camera exposure: " + kind)
		main.model.settings.camera.brightness_gain = gain
		main.world.update_world()
		var first: int = rune.targets[0]
		check(rune.receive_hit(first, 0.0, main.model.time).accepted, "normal radial hit drives the light transition")
		main.world.update_world()
		if paired:
			check(count_visible(view.frames) == 0 and count_visible(view.bars) == 0, "first target hit does not prematurely display the next group's fraction")
			check(count_visible(view.arrows) == 1 and count_visible(view.score_marks[first]) == 6, "paired first hit shows score and leaves only the second target's arrows")
			rune.receive_hit(rune.targets[0], 0.0, main.model.time)
			main.world.update_world()
			check(count_visible(view.frames) == 0 and count_visible(view.marks) == 0 and count_visible(view.arrows) == 0 and count_visible(view.bars) == 0, "2027 group switch extinguishes all blade lights")
			step_rune(0.20001)
			main.world.update_world()
			check(count_visible(view.frames) == 0 and count_visible(view.bars) == 5, "next pair uses five progress bars without permanent completed outlines")
			for bar in view.bars:
				check(is_equal_approx(bar.scale.y, 0.2) and bar.material_override.emission_enabled, "first completed group shows illuminated one-fifth progress on every arm")
			for scored in view.score_marks:
				check(count_visible(scored) == 0, "previous pair's score lamps do not persist into the next pair")
			var next: int = rune.targets[0]
			rune.receive_hit(next, 0.0, main.model.time)
			main.world.update_world()
			check(is_equal_approx(view.bars[0].scale.y, 0.2), "second group's first hit does not advance progress until group change")
		else:
			if rune.blackout_end != INF:
				check(count_visible(view.frames) == 0 and count_visible(view.bars) == 0 and count_visible(view.marks) == 0 and count_visible(view.arrows) == 0, "2027 small switch also extinguishes completed arms")
				step_rune(0.20001)
				main.world.update_world()
			check(view.frames[first].visible and view.bars[first].visible and not view.arrows[first].visible and not view.marks[first].visible, "single-target hit replaces arrows with completed outline and full bar: " + kind)
			check(count_visible(view.score_marks[first]) == (6 if rune.big else 1), "single-target completed target shows ring feedback")
		await capture("lights-" + kind + "-hit")
		# Start a fresh attempt through the same button before completing the remaining transitions.
		main.model.paused = false
		main.rune_start.pressed.emit()
		main.model.paused = true
		for _group in range(5):
			if rune.blackout_end != INF:
				step_rune(rune.blackout_end - main.model.time + 0.00001)
			rune.receive_hit(rune.targets[0], 0.0, main.model.time)
			if paired:
				rune.receive_hit(rune.targets[0], 0.0, main.model.time)
		main.world.update_world()
		check(rune.state == "activated" and count_visible(view.frames) == 5 and count_visible(view.bars) == 5, "overall success lights all five frames and full bars: " + kind)
		check(count_visible(view.arrows) == 0 and count_visible(view.marks) == 0, "overall success no longer displays pending target arrows")
		for bar in view.bars:
			check(is_equal_approx(bar.scale.y, 1.0), "complete rune has full-length middle bars")
		await capture("lights-" + kind + "-complete")
		main.model.paused = false
		main.rune_start.pressed.emit()
		main.model.paused = true
		main.world.update_world()
		check(count_visible(view.frames) == 0 and count_visible(view.bars) == 0, "restarting clears every completed outline and progress fraction")


func collect_glare(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.is_visible_in_tree() and node.material_override is ShaderMaterial:
		if node.material_override.shader.resource_path.ends_with("_glow.gdshader"):
			result.append(node)
	for child in node.get_children():
		collect_glare(child, result)


func test_local_glare() -> void:
	select_target("small_rune_2025")
	main.model.paused = false
	main.rune_start.pressed.emit()
	main.model.paused = true
	main.fields["camera.brightness_gain"].value = 1.0
	var lit = await capture("local-glare-lit")
	var raw = main.world.raw_sensor_viewport.get_texture().get_image()
	var strip = Rect2i(0, 0, 160, lit.get_height())
	var source_background = raw.get_region(strip)
	var sensor_background = lit.get_region(strip)
	source_background.convert(Image.FORMAT_RGB8)
	sensor_background.convert(Image.FORMAT_RGB8)
	var source_data = source_background.get_data()
	var sensor_data = sensor_background.get_data()
	var max_difference = 0
	for i in range(source_data.size()):
		max_difference = maxi(max_difference, absi(int(source_data[i]) - int(sensor_data[i])))
	check(max_difference <= 1, "camera preserves sharp background pixels without a full-image blur")
	var glows: Array[MeshInstance3D] = []
	collect_glare(main.world.rune_view, glows)
	check(not glows.is_empty(), "pending rune has local emitting-ring and arrow glare")
	for glow in glows:
		glow.visible = false
	var unlit = await capture("local-glare-hidden")
	var changed = 0
	for y in range(0, lit.get_height(), 2):
		for x in range(0, lit.get_width(), 2):
			var before = unlit.get_pixel(x, y)
			var after = lit.get_pixel(x, y)
			if maxf(after.r - before.r, maxf(after.g - before.g, after.b - before.b)) > 0.02:
				changed += 1
	check(changed > 50, "local glare adds visible light around emitting geometry in actual camera pixels")
	for glow in glows:
		glow.visible = true


func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.no_ipc = true
	root.add_child(main)
	await process_frame
	check(main.model.settings.appearance.robot == "infantry_3_2026" and main.model.settings.appearance.team == "blue", "default startup is blue infantry three")
	check(main.armor_controls.is_visible_in_tree() and not main.rune_controls.is_visible_in_tree(), "armor shows only armor controls")
	check(main.world.plates.size() == 4 and main.world.rune_view == null, "armor renders four plates and no rune")
	main.fields["target.center.x"].value = 6.0
	main.fields["target.omega"].value = 8.0
	select_target("small_rune_2027")
	check(main.rune_controls.is_visible_in_tree() and not main.armor_controls.is_visible_in_tree(), "rune shows only rune controls")
	check(not main.armor_model_controls.is_visible_in_tree() and not main.fields["weapon.damage"].get_parent().is_visible_in_tree(), "all armor-only controls disappear")
	check(main.world.plates.is_empty() and main.world.rune_view != null and main.world.rune_view.faces.size() == 5, "five rune blades replace all armor meshes")
	main.fields["rune.forward"].value = 5.0
	main.fields["rune.lateral"].value = 0.5
	main.fields["rune.heading"].value = 15.0
	check(is_equal_approx(main.model.settings.target.center.x, 6) and is_equal_approx(main.model.settings.target.omega, 8), "rune edit does not overwrite armor settings")
	check(is_equal_approx(main.model.settings.rune.heading, deg_to_rad(15)), "heading input is degrees, stored angle is radians")
	main.rune_start.pressed.emit()
	main.model.paused = true
	main.world.update_world()
	check(main.model.rune.targets.size() == 1, "activation button starts small rune")
	await capture("small-active")
	select_target("infantry_3_2026")
	check(main.armor_controls.is_visible_in_tree() and not main.rune_controls.is_visible_in_tree(), "switch back hides every rune control")
	check(main.world.rune_view == null and main.world.plates.size() == 4, "switch back removes every rune mesh")
	check(not main.model.camera_observation().armors.is_empty(), "switching back frames armor without resetting the round")
	check(absf(main.pitch_input.value - rad_to_deg(main.model.pitch)) <= 0.005 + 1e-9, "manual angle display follows reframed gimbal within its 0.01-degree increment")
	check(is_equal_approx(main.fields["target.center.x"].value, 6) and is_equal_approx(main.fields["target.omega"].value, 8), "armor profile restored after rune")
	main.fields["target.center.x"].value = 7.0
	select_target("big_rune_2027")
	check(is_equal_approx(main.model.settings.rune.forward, 5) and is_equal_approx(main.model.settings.rune.lateral, 0.5), "rune placement survived armor edits")
	check(is_equal_approx(main.fields["rune.heading"].value, 15), "rune heading restored")
	main.model.paused = false
	main.rune_start.pressed.emit()
	main.model.paused = true
	check(main.model.rune.targets.size() == 2 and main.model.snapshot().mode == 3, "big selection starts independent double-target phase")
	await capture("big-active")
	select_target("infantry_3_2026")
	check(is_equal_approx(main.model.settings.target.center.x, 7), "second armor edit retained")
	select_target("big_rune_2025")
	main.model.paused = false
	main.rune_start.pressed.emit()
	main.model.step(0.101)
	main.model.paused = true
	check(main.model.rune.year == 2025 and main.model.rune.targets.size() == 1, "2025 big button immediately lights one blade")
	check(main.model.snapshot().appearance.robot == "big_rune_2025" and main.model.snapshot().mode == 3, "IPC preserves season name and big mode")
	await capture("big-active-2025")
	select_target("small_rune_2025")
	main.model.paused = false
	main._update_status()
	check(not main.rune_start.disabled and main.rune_start.text.contains("开始"), "2025 small has the same manual start button")
	main.rune_start.pressed.emit()
	check(main.model.rune.year == 2025 and not main.model.rune.big and main.model.rune.targets.size() == 1, "2025 small lights immediately after clicking")
	main.rune_start.pressed.emit()
	check(main.model.rune.state == "active" and main.model.rune.groups == 0, "button can restart during active practice")
	main.model.paused = true
	await capture("small-active-2025")
	for preset in main.Presets.ROBOTS.values():
		check(preset.label.contains(str(preset.year)), "every selector label includes its year")
	select_target("infantry_3_2026")
	check(is_equal_approx(main.model.settings.target.center.x, 7), "armor profile survives switches across both rune seasons")

	await test_lights()
	await test_local_glare()
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: %d rune UI checks" % checks)
		quit(0)
	else:
		print("FAILED: %d / %d" % [failures.size(), checks])
		quit(1)
