extends Area3D
class_name ItemPickup

@export var item: Item
@export var amount: int = 1

var _player: Node
var _tag: ItemTag

func _ready() -> void:
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)
	connect("mouse_entered", _on_mouse_entered)
	connect("mouse_exited", _on_mouse_exited)
	connect("input_event", _on_input_event)

	var layer = get_tree().get_root().get_node_or_null("WorldRoot/ItemTagLayer")

	var label = Label.new()
	#label.text = "Hello from canvas layer!"
	#label.position = Vector2(100, 100)
	#layer.add_child(label)

	_tag = ItemTag.new()
	_tag.text = item.item_name
	_tag.tooltip_text = "%s\n%s" % [item.item_name, item.description]
	_tag.target = self
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

func _on_input_event(camera: Node, event: InputEvent, position: Vector3, normal: Vector3, shape_idx: int) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_collect()

func _collect() -> void:
		if _player and item:
				_player.add_item(item, amount)
		if _tag:
				_tag.queue_free()
		queue_free()
