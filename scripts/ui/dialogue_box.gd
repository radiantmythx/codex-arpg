extends Control
class_name DialogueBox
## Simple textbox used for NPC conversations.
##
## The node builds its UI elements in `_ready` so no additional scene is
## required.  Set `pause_mode` to `PROCESS` so it remains interactive while the
## rest of the game is paused.
##
## Call `start_conversation(npc, player, camera)` to begin talking.  The camera
## is temporarily repositioned to show both characters and restored when the
## conversation ends.

var _npc: Node
var _player: Node3D
var _camera: Camera3D
var _camera_transform: Transform3D
var _line_index: int = 0

var _label: Label
var _talk_button: Button
var _trade_button: Button
var _quit_button: Button
var _next_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false

	var panel := Panel.new()
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(panel)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label.anchor_right = 1.0
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(_label)

	var buttons := HBoxContainer.new()
	buttons.anchor_top = 1.0
	buttons.anchor_right = 1.0
	buttons.offset_bottom = -10
	buttons.offset_right = -10
	buttons.offset_left = 10
	buttons.offset_top = -40
	buttons.grow_vertical = Control.GROW_DIRECTION_END
	panel.add_child(buttons)

	_talk_button = Button.new()
	_talk_button.text = "Talk"
	_talk_button.pressed.connect(_on_talk_pressed)
	buttons.add_child(_talk_button)

	_trade_button = Button.new()
	_trade_button.text = "Trade"
	_trade_button.pressed.connect(_end_conversation)
	buttons.add_child(_trade_button)

	_quit_button = Button.new()
	_quit_button.text = "Quit"
	_quit_button.pressed.connect(_end_conversation)
	buttons.add_child(_quit_button)

	_next_button = Button.new()
	_next_button.text = "Next"
	_next_button.pressed.connect(_show_next_line)
	_next_button.visible = false
	buttons.add_child(_next_button)

func start_conversation(npc: Node, player: Node3D, camera: Camera3D) -> void:
	## Opens the dialogue box and pauses the game.
	_npc = npc
	_player = player
	_camera = camera
	_camera_transform = camera.global_transform
	_line_index = 0
	_show_options()
	get_tree().paused = true
	_reposition_camera()
	visible = true

func _reposition_camera() -> void:
	if not _camera or not _npc or not _player:
		return
	var mid = (_player.global_transform.origin + _npc.global_transform.origin) * 0.5
	var offset = (_camera_transform.origin - mid).normalized() * 6.0
	_camera.global_transform.origin = mid + offset + Vector3.UP * 2.0
	_camera.look_at(mid, Vector3.UP)

func _show_options() -> void:
	_label.text = _npc.dialogue_lines[0] if _npc.dialogue_lines.size() > 0 else ""
	_talk_button.visible = true
	_trade_button.visible = _npc.can_trade
	_quit_button.visible = true
	_next_button.visible = false

func _on_talk_pressed() -> void:
	_line_index = 0
	_show_next_line()

func _show_next_line() -> void:
	if _npc.dialogue_lines.is_empty():
		_show_options()
		return
	if _line_index < _npc.dialogue_lines.size():
		_label.text = _npc.dialogue_lines[_line_index]
		_line_index += 1
		_talk_button.visible = false
		_trade_button.visible = false
		_quit_button.visible = false
		_next_button.visible = true
	else:
		_show_options()

func _end_conversation() -> void:
	visible = false
	get_tree().paused = false
	if _camera:
		_camera.global_transform = _camera_transform
	_npc = null
	_player = null
	_camera = null
