extends SceneTree
## Headless smoke test: loads and instantiates the main scene.
## Exit 0 = OK, exit 1 = failed to load/instantiate.
##
## Usage:
##   godot --headless --script tests/scene_load_test.gd

const MAIN_SCENE := "res://scenes/ludo_game.tscn"

func _initialize() -> void:
	quit(_check_scene(MAIN_SCENE))


func _check_scene(path: String) -> int:
	var packed: PackedScene = load(path)
	if packed == null:
		printerr("SCENE_LOAD FAIL: Cannot load ", path)
		return 1

	var node: Node = packed.instantiate()
	if node == null:
		printerr("SCENE_LOAD FAIL: Cannot instantiate ", path)
		return 1

	get_root().add_child(node)
	print("SCENE_LOAD OK: ", path)
	node.queue_free()
	return 0
