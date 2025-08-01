extends Area3D
class_name ItemPickup

@export var item: Item
@export var amount: int = 1

func _ready() -> void:
	connect("body_entered", _on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.has_method("add_item") and item:
		body.add_item(item, amount)
		queue_free()
