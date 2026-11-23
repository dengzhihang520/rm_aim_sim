extends SceneTree
const CAD = preload("res://scripts/cad_armor.gd")
const Assets = preload("res://scripts/visual_assets.gd")
const Settings = preload("res://scripts/settings.gd")
const Presets = preload("res://scripts/presets.gd")
var failures = 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		print("FAIL ",message)
func _initialize() -> void:
	var settings = Settings.defaults()
	for robot in ["infantry_3_2026","hero_2026"]:
		Presets.apply_robot(settings,robot)
		var cad = CAD.instantiate(settings.target)
		var actual = Assets.mesh_bounds(cad)
		var spec = CAD.specification(settings.target)
		var lo = Vector3(spec.bounds.minimum[0],spec.bounds.minimum[1],spec.bounds.minimum[2])
		var hi = Vector3(spec.bounds.maximum[0],spec.bounds.maximum[1],spec.bounds.maximum[2])
		check(actual.position.distance_to(lo)<0.00025,robot+" mesh minimum agrees with source CAD")
		check(actual.end.distance_to(hi)<0.00025,robot+" mesh maximum agrees with source CAD")
		check(absf(actual.size.z-0.019)<0.00025,robot+" real thickness is19mm")
		check(absf(Presets.extent(settings.target)-0.55)<0.00001,robot+" rotating envelope stays550mm")
		print(robot," mesh dimensions mm=",actual.size*1000.0," front max=",actual.end.z," scale=",cad.scale)
		cad.free()
	print("CAD_GEOMETRY failures=",failures)
	quit(0 if failures==0 else 1)
