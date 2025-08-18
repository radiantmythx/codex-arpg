class_name ItemPickup
extends Area3D

@export var item: Item
@export var amount: int = 1
@export var item_tag_layer_path: NodePath = NodePath("/root/WorldRoot/ItemTagLayer")

var _player: Node
var _tag: ItemTag
var _layer: ItemTagLayer
var _notifier: VisibleOnScreenNotifier3D
var _tag_visible: bool = false

func _ready() -> void:
		connect("body_entered", _on_body_entered)
		connect("body_exited", _on_body_exited)
		connect("mouse_entered", _on_mouse_entered)
		connect("mouse_exited", _on_mouse_exited)
		connect("input_event", _on_input_event)

		_layer = get_tree().get_root().get_node_or_null(item_tag_layer_path)

	_tag = ItemTag.new()
	_tag.target = self
	_tag.set_item(item)
	await get_tree().process_frame
	if _layer:
		_layer.add_tag(_tag)
		_tag_visible = true
	else:
		add_child(_tag) # fallback so tag still appears during testing
		_tag_visible = true
	_tag.connect("pressed", Callable(self, "_collect"))

		_notifier = VisibleOnScreenNotifier3D.new()
		add_child(_notifier)
		_notifier.connect("screen_exited", Callable(self, "_on_screen_exited"))
		_notifier.connect("screen_entered", Callable(self, "_on_screen_entered"))

func _on_body_entered(body: Node) -> void:
	if body.has_method("add_item"):
			_player = body

func _on_body_exited(body: Node) -> void:
	if body == _player:
			_player = null

func _on_mouse_entered() -> void:
	pass

func _on_mouse_exited() -> void:
	pass

func _on_input_event(
		_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int
) -> void:
		if (
				event is InputEventMouseButton
				and event.pressed
				and event.button_index == MOUSE_BUTTON_LEFT
		):
				_collect()

func _collect() -> void:
	if _player and item:
					_player.add_item(item, amount)
					if _layer and _tag:
									_layer.remove_tag(_tag)
					elif _tag:
									_tag.queue_free()
					get_parent().queue_free()

func _on_screen_exited() -> void:
				if _tag_visible:
								if _layer and _tag:
												_layer.hide_tag(_tag)
								elif _tag:
												_tag.visible = false
												_tag.set_process(false)
								_tag_visible = false

func _on_screen_entered() -> void:
				if not _tag_visible:
								if _layer and _tag:
												_layer.show_tag(_tag)
								elif _tag:
												_tag.visible = true
												_tag.set_process(true)
								_tag_visible = true
