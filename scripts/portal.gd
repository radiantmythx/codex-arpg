extends Interactable
class_name Portal
## Example interactable that teleports the player after confirming via UI.
##
## The portal displays a UI when interacted with. The tree is paused while
## the UI is visible and resumes once the UI emits its `closed` signal.
## When the player confirms travel the portal moves them to
## `destination_path`.
##
## This script relies solely on NodePaths so the `Portal.tscn` scene does not
## need to be edited. Attach this script to the existing portal scene and set
## the paths in the inspector.

@export var destination_path: NodePath ## Node3D the player should be moved to.
@export var ui_path: NodePath ## Control that handles portal interaction.

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
	if _current_player and _destination:
		_current_player.global_transform.origin = _destination.global_transform.origin
		_current_player.position.y = 0
		
