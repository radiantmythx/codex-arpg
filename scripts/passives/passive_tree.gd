class_name PassiveTree
extends Control

@export var player_path: NodePath
@export var nodes_parent_path: NodePath

var _player
var _nodes: Array[PassiveNode] = []
var _lines_layer: Node2D
var available_points: int = 0
var root_node: PassiveNode

func _ready() -> void:
	if player_path != NodePath():
		_player = get_node_or_null(player_path)
	var parent: Node = self
	if nodes_parent_path != NodePath():
		parent = get_node(nodes_parent_path)
	for child in parent.get_children():
		if child is PassiveNode:
			var node: PassiveNode = child
			node.tree = self
			_nodes.append(node)
			if node.is_root:
				root_node = node
				node.allocated = true
				node.apply_effect(_player)
	_lines_layer = Node2D.new()
	add_child(_lines_layer)
	_lines_layer.z_index = -1
	generate_lines()

func add_points(count: int) -> void:
	available_points += count

func request_allocate(node: PassiveNode) -> void:
	if can_allocate(node):
		available_points -= node.cost
		node.allocated = true
		node.apply_effect(_player)
		generate_lines()

func can_allocate(node: PassiveNode) -> bool:
	if node.allocated:
		return false
	if available_points < node.cost:
		return false
	if node.is_root:
		return true
	var connected = _get_connected_allocated()
	for n in node.get_connected_nodes():
		if n in connected:
			return true
	return false

func _get_connected_allocated() -> Array:
	if not root_node:
		return []
	var visited: Array = []
	var queue: Array = [root_node]
	while queue.size() > 0:
		var current: PassiveNode = queue.pop_front()
		if current in visited:
			continue
		visited.append(current)
		for n in current.get_connected_nodes():
			if n.allocated:
				queue.append(n)
	return visited

func generate_lines() -> void:
	for c in _lines_layer.get_children():
		c.queue_free()
	for node in _nodes:
		for conn in node.get_draw_connections():
			var target: PassiveNode = conn["target"]
			if node.get_instance_id() < target.get_instance_id():
				var line := Line2D.new()
				line.default_color = conn["color"]
				line.width = 2
				line.add_point(node.position)
				line.add_point(target.position)
				_lines_layer.add_child(line)
