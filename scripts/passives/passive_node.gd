class_name PassiveNode
extends TextureButton

@export var connections: Array[NodePath] = []
@export var is_root: bool = false
@export var cost: int = 1

var tree: PassiveTree = null
var allocated: bool = false

func _ready() -> void:
	connect("pressed", Callable(self, "_on_pressed"))

func _on_pressed() -> void:
	if tree:
		tree.request_allocate(self)

func get_connected_nodes() -> Array:
	var result: Array = []
	for p in connections:
		var n = get_node_or_null(p)
		if n:
			result.append(n)
	return result

func get_draw_connections() -> Array:
	# Returns dictionaries {"target": PassiveNode, "color": Color}
	var arr: Array = []
	for n in get_connected_nodes():
		arr.append({"target": n, "color": Color.WHITE})
	return arr

func apply_effect(_player) -> void:
	pass

func remove_effect(_player) -> void:
	pass
