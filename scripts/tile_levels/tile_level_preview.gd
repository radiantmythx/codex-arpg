@tool
class_name TileLevelPreview
extends EditorScript

# Editor helper that builds a sample scene from a `TileLevelSettings` resource.
# Set `settings_path` and optionally `output_path`, then run the script from the
# Godot editor (File → Run) to generate a `.tscn` you can inspect.

@export_file("*.tres") var settings_path: String = "res://resources/level_gen/floating_islands.tres"
@export_file("*.tscn") var output_path: String = "res://generated_level.tscn"

func _run() -> void:
	if settings_path == "":
		push_error("TileLevelPreview: settings_path is empty")
		return
	var settings: TileLevelSettings = load(settings_path)
	if not settings:
		push_error("TileLevelPreview: could not load settings resource")
		return
	var generator := TileLevelGenerator.new()
	var root := generator.generate(settings)
	print("Assigning owners recursive...")
	_assign_owners_recursive(root, root)
	print("Owners assigned!")
	print("Attempting to pack scene...")
	var t0 := Time.get_ticks_msec()
	var packed := PackedScene.new()
	var err2 := packed.pack(root)
	var dt := Time.get_ticks_msec() - t0
	print("pack %s took %sms" % [err2, dt])
	if err2 != OK:
		push_error("Could not pack scene")
		return
	print("Scene packed!")
	print("Attempting to save scene...")
	var err = ResourceSaver.save(packed, output_path)
	if err == OK:
		print("Saved generated level to %s" % output_path)
	else:
		push_error("Could not save generated level: %s" % err)

func _assign_owners_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_assign_owners_recursive(child, owner)
