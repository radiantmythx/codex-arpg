class_name ItemPickup
extends Area3D

@export var item: Item
@export var amount: int = 1
@export var item_tag_layer_path: NodePath = NodePath("/root/WorldRoot/ItemTagLayer")

var _player: Node
var _tag: ItemTag


func _ready() -> void:
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)
	connect("mouse_entered", _on_mouse_entered)
	connect("mouse_exited", _on_mouse_exited)
	connect("input_event", _on_input_event)

	var layer: ItemTagLayer = get_tree().get_root().get_node_or_null(item_tag_layer_path)

	_tag = ItemTag.new()
	_tag.target = self
	_tag.set_item(item)
	layer.add_child(_tag)
	_tag.connect("pressed", Callable(self, "_collect"))


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
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_collect()


func _collect() -> void:
	if _player and item:
		_player.add_item(item, amount)
		if _tag:
			_tag.queue_free()
		get_parent().queue_free()
		
