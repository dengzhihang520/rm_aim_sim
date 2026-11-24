extends SceneTree

const Presets = preload("res://scripts/presets.gd")
const Assist = preload("res://scripts/aim_assist.gd")
var main: Node
var checks = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)


func select_target(name: String) -> void:
	for index in range(main.robot_select.item_count):
		if main.robot_select.get_item_metadata(index) == name:
			main.robot_select.select(index)
			main.robot_select.item_selected.emit(index)
			return
	check(false, "missing target " + name)


func capture(name: String) -> void:
	main.world.update_world()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.tools/verification/outpost2026")
	var output = "res://.tools/verification/outpost2026/" + name
	main.world.sensor_viewport.get_texture().get_image().save_png(output + "-sensor.png")
	root.get_texture().get_image().save_png(output + "-gui.png")


func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.no_ipc = true
	root.add_child(main)
	main.model.paused = true
	var key: Array = main.model.camera_observation().K.duplicate()
	var vehicle: Dictionary = main.model.settings.target.duplicate(true)
	select_target("outpost_2026")
	check(main.outpost_controls.is_visible_in_tree(), "outpost controls are visible")
	check(not main.armor_controls.visible and not main.armor_model_controls.visible and not main.rune_controls.visible,
		"vehicle and rune controls are hidden")
	check(not main.fields["weapon.damage"].get_parent().visible, "outpost does not expose a rule-breaking damage override")
	check(main.world.plates.size() == 3 and main.world.outpost_view != null and main.world.rune_view == null,
		"outpost replaces all four vehicle plates and rune meshes")
	check(main.model.settings.target == vehicle, "outpost selection preserves the vehicle profile")
	check(main.model.camera_observation().K == key, "selection does not change calibration")
	check(not main.model.camera_observation().armors.is_empty(), "new target is automatically brought into the camera view")
	check(main.world.outpost_view.guidance.visible, "live outpost has a green guidance lamp")
	main.world.update_world()
	for index in range(main.world.plates.size()):
		var plate: Node3D = main.world.plates[index]
		var pose: Dictionary = main.model.armor_pose(index, main.model.time)
		check(plate.basis.z.is_equal_approx(main.world.to_engine(pose.normal)),
			"rendered armor shares the physical downward normal")
		check(pose.normal.z < 0.0, "rendered outpost armor faces downward")
		check(plate.get_node("ArmorSticker").texture != null, "official outpost mark is loaded")
		var mark: Image = plate.get_node("ArmorSticker").texture.get_image()
		check(mark.get_pixel(295, 199).a > 0.9 and mark.get_pixel(295, 150).a < 0.1,
			"outpost has a white top dot inside an open head, unlike the base badge")
		check(mark.get_pixel(295, 340).a > 0.9 and mark.get_pixel(295, 520).a < 0.1,
			"outpost retains the inner vertical stem and lower opening")
		check(plate.get_node("LampGlare").visible, "each active plate has local lightbar glare")
	main.fields["outpost.forward"].value = 8.0
	main.fields["outpost.lateral"].value = 0.25
	main.fields["outpost.base_height"].value = 0.40
	main.fields["weapon.speed"].value = 23.123
	check(absf(main.model.settings.weapon.speed - 23.12) < 1e-9, "ordinary fields retain two-decimal editing")
	check(main.model.settings.outpost.forward == 8.0 and main.model.settings.outpost.lateral == 0.25,
		"independent placement controls apply")
	check(absf(main.model.armor_pose(0, main.model.time).center.z - 1.514) < 1e-6, "base-height edit moves modules")
	check(main.model.settings.target == vehicle and main.model.camera_observation().K == key,
		"placement and speed edits cannot alter vehicle geometry or intrinsics")
	var start: float = main.model.outpost.started_at
	var direction: float = main.model.outpost.direction
	main.team_select.select(1)
	main.team_select.item_selected.emit(1)
	check(main.model.outpost.direction == direction and main.model.outpost.started_at == start,
		"team selection preserves direction and running time")
	check(main.world.plate_materials[0].albedo_color == Presets.team_color("red"), "team color reaches actual LEDs")
	main.fields["outpost.forward"].value = 4.0
	main.fields["outpost.lateral"].value = 0.0
	main.fields["outpost.base_height"].value = 0.30
	main.fields["weapon.speed"].value = 23.0
	main.fields["outpost.opponent_base_open"].button_pressed = true
	main.model.paused = false
	main.model.step(3.0)
	main.model.paused = true
	check(main.model.outpost.snapshot(main.model.time).state == "stopped", "base-open control stops and returns the armor")
	main.fields["outpost.opponent_base_open"].button_pressed = false
	check(main.model.outpost.speed(main.model.time) == 0.0, "clearing the checkbox does not restart the armor")
	await capture("outpost-red")
	main.team_select.select(0)
	main.team_select.item_selected.emit(0)
	await capture("outpost-blue")
	main.world.first_person = false
	main._sync_view()
	await capture("outpost-third-person")
	var solution: Dictionary = Assist.solve(main.model, false)
	check(not solution.is_empty(), "existing local aiming helper supports three visible modules")
	if not solution.is_empty():
		main.model.paused = false
		var command = {"control": true, "fire": false, "yaw": solution.yaw, "pitch": solution.pitch}
		main.model.set_command(command)
		main.model.step(1.0)
		command.fire = true
		main.model.set_command(command)
		main.model.step(10.0)
		main.model.stop()
		main.model.step(0.5)
		main.model.paused = true
	main.world.update_world()
	main._update_status()
	check(main.model.health == 0, "physical firing destroys the rendered outpost")
	check(not main.world.outpost_view.guidance.visible and not main.world.outpost_view.indicator.visible,
		"death extinguishes guidance and body indicator")
	for plate in main.world.plates:
		check(not plate.get_node("LampGlare").visible, "death extinguishes armor glare")
	await capture("outpost-destroyed")
	var stats: Dictionary = main.model.stats.duplicate()
	main.model.paused = false
	main._update_status()
	check(not main.outpost_rebuild.disabled, "dead outpost exposes the normal training rebuild button")
	main.outpost_rebuild.pressed.emit()
	main.model.paused = true
	main.world.update_world()
	check(main.model.health == 750 and main.world.outpost_view.guidance.visible,
		"rebuild button restores health and visible lamps")
	check(main.model.outpost.speed(main.model.time) == 0.0 and main.model.stats == stats,
		"rebuild preserves stopped state and cumulative results")
	select_target("big_rune_2025")
	check(main.world.outpost_view == null and main.world.rune_view != null and main.world.plates.is_empty(),
		"rune selection removes the whole outpost")
	select_target("infantry_3_2026")
	check(main.world.outpost_view == null and main.world.rune_view == null and main.world.plates.size() == 4,
		"vehicle selection restores exactly four plates")
	check(main.model.settings.target == vehicle and main.model.camera_observation().K == key,
		"vehicle profile and calibration survive category switches")
	main.queue_free()
	await process_frame
	print(("PASS: " if failures.is_empty() else "FAILED: ") + str(checks) + " outpost UI checks " + str(failures))
	quit(0 if failures.is_empty() else 1)
