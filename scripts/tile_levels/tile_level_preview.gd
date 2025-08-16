@tool
class_name TileLevelPreview
extends EditorScript

# Editor helper that builds a sample scene from a `TileLevelSettings` resource.
# Set `settings_path` and optionally `output_path`, then run the script from the
# Godot editor (File → Run) to generate a `.tscn` you can inspect.

@export_file("*.tres") var settings_path: String
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
    var packed := PackedScene.new()
    packed.pack(root)
    var err := ResourceSaver.save(output_path, packed)
    if err == OK:
        print("Saved generated level to %s" % output_path)
    else:
        push_error("Could not save generated level: %s" % err)

