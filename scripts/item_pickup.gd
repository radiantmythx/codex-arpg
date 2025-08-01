extends Area3D
class_name ItemPickup

@export var item: Item
@export var amount: int = 1

var _player: Node
var _name_label: Label3D
var _tooltip: Label3D

func _ready() -> void:
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)
	connect("mouse_entered", _on_mouse_entered)
	connect("mouse_exited", _on_mouse_exited)
	connect("input_event", _on_input_event)

	_name_label = Label3D.new()
	_name_label.text = item.item_name
	_name_label.billboard = true
	add_child(_name_label)

	_tooltip = Label3D.new()
	_tooltip.text = "%s\n%s" % [item.item_name, item.description]
	_tooltip.billboard = true
	_tooltip.visible = false
	_tooltip.position.y += 0.5
	add_child(_tooltip)

func _on_body_entered(body: Node) -> void:
	if body.has_method("add_item"):
		_player = body

func _on_body_exited(body: Node) -> void:
	if body == _player:
		_player = null

func _on_mouse_entered() -> void:
	_tooltip.visible = true

func _on_mouse_exited() -> void:
	_tooltip.visible = false

func _on_input_event(camera: Node, event: InputEvent, position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _player and item:
			_player.add_item(item, amount)
			queue_free()
