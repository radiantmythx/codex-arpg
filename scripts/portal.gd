extends Interactable
class_name Portal
## Interactable portal that generates a new procedural level when used.
##
## The portal displays a UI when interacted with. The tree is paused while
## the UI is visible and resumes once the UI emits its `closed` signal. When
## the player confirms travel the current level (node named "GeneratedLevel")
## is removed, a new one is generated from `level_settings_path` and the
## player/camera are moved to the `PlayerSpawn` marker.
##
## The portal hides itself until the boss in the generated level is killed.
## When the boss emits its `died` signal the portal reappears at the boss's
## last position, allowing the player to generate the next level.

@export var destination_path: NodePath ## Unused legacy export retained for compatibility.
@export var ui_path: NodePath ## Control that handles portal interaction.
@export_file("*.tres") var level_settings_path: String = "res://resources/level_gen/floating_islands.tres"

var _destination: Node3D
var _ui: Node
var _current_player: Node

func _ready() -> void:
	super._ready()
	if destination_path != NodePath():
		_destination = get_node_or_null(destination_path)
	if ui_path != NodePath():
		_ui = get_node_or_null(ui_path)
		if _ui and _ui is CanvasItem:
			_ui.visible = false

func interact(player: Node) -> void:
	## Show the portal UI and pause the game.
	_current_player = player
	if _ui and _ui is CanvasItem:
		_ui.show()
		get_tree().paused = true
		if _ui.has_signal("travel_requested"):
			_ui.connect("travel_requested", Callable(self, "_on_travel_requested"), CONNECT_ONE_SHOT)
		if _ui.has_signal("closed"):
			_ui.connect("closed", Callable(self, "_on_ui_closed"), CONNECT_ONE_SHOT)
	else:
		_teleport()

func _on_travel_requested() -> void:
	_teleport()
	_close_ui()

func _on_ui_closed() -> void:
	print("on ui closed!")
	_close_ui()

func _close_ui() -> void:
        if _ui and _ui is CanvasItem:
                _ui.hide()
        get_tree().paused = false
        _current_player = null

func _teleport() -> void:
        if not _current_player:
                return
        var scene_root := get_tree().current_scene

        # Remove any previously generated level.
        var existing := scene_root.get_node_or_null("GeneratedLevel")
        if existing:
                existing.queue_free()

        # Generate the new level using the runtime helper.
        var runtime := TileLevelRuntime.new()
        runtime.settings_path = level_settings_path
        var level := runtime.generate()
        if level:
                scene_root.add_child(level)

                # Move the player and camera to the PlayerSpawn marker.
                var spawn := level.get_node_or_null("PlayerSpawn")
                if spawn and _current_player is Node3D:
                        var player_3d: Node3D = _current_player
                        var cam := get_viewport().get_camera_3d()
                        var offset := Vector3.ZERO
                        if cam:
                                offset = cam.global_position - player_3d.global_position
                        player_3d.global_position = spawn.global_position
                        player_3d.position.y = 0
                        if cam:
                                cam.global_position = player_3d.global_position + offset

                # Hide the portal until the boss is defeated.
                visible = false
                remove_from_group("interactable")

                # Find the boss and respawn the portal when it dies.
                for child in level.get_children():
                        if child.is_in_group("enemy") and child.has_variable("tier") and child.tier == child.Tier.BOSS:
                                child.connect("died", Callable(self, "_on_boss_died").bind(child), CONNECT_ONE_SHOT)
                                break

## Called when the boss dies. Repositions and re-enables the portal so the
## player can generate another level.
func _on_boss_died(boss: Node) -> void:
        if not boss or not (boss is Node3D):
                return
        global_transform.origin = (boss as Node3D).global_transform.origin
        global_transform.origin.y = 0
        visible = true
        add_to_group("interactable")
		
