class_name TileLevelRuntime
extends Node

## Runtime helper that builds a procedural level from a
## `TileLevelSettings` resource. This mirrors the editor-only
## `TileLevelPreview` but is safe to use in-game.
##
## Call `generate()` to produce a level node or `generate_into(parent)`
## to add it directly to the scene tree. The returned node will be
## named `GeneratedLevel` by `TileLevelGenerator`.

@export_file("*.tres") var settings_path: String = "res://resources/level_gen/floating_islands.tres"

func _load_settings() -> TileLevelSettings:
	if settings_path == "":
		push_error("TileLevelRuntime: settings_path is empty")
		return null
	var settings: TileLevelSettings = load(settings_path)
	if not settings:
		push_error("TileLevelRuntime: could not load settings resource")
	return settings

## Generates a level and returns the root node without adding it to the
## scene tree.
func generate() -> Node3D:
	var settings := _load_settings()
	if not settings:
		return null
	var generator := TileLevelGenerator.new()
	return generator.generate(settings)

## Generates a level and adds it as a child of `parent`. The generated
## node is returned for convenience.
func generate_into(parent: Node) -> Node3D:
	var level := generate()
	if level and parent:
		parent.add_child(level)
	return level
