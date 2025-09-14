class_name Minimap
extends Control
"""
Renders a 2D minimap of the current procedurally generated level with a
simple fog-of-war system. The map reveals walkable tiles as the player
moves and overlays icons for nearby enemies and the boss once discovered.
Attach this script to a Control node. Set its size/anchors in the editor.
"""

@export var player_path: NodePath  ## Path to the player `Node3D`.
@export var map_scale: float = 4.0  ## Pixel size for each tile on the map.
@export var enemy_reveal_distance: float = 30.0  ## World units to show enemies.
@export var wall_color: Color = Color(0.5, 0.7, 1, 0.8)  ## Color for walls on the map.
@export var player_color: Color = Color(0.2, 0.6, 1)  ## Player icon color.
@export var enemy_color: Color = Color(1, 0, 0)  ## Enemy icon color.
@export var boss_color: Color = Color(1, 0, 1)  ## Boss icon color.
@export var reveal_radius: int = 3  ## Radius (in tiles) for fog-of-war revealing.

var _player: Node3D
var _level: Node3D
var _level_size: Vector2i = Vector2i.ZERO
var _tile_size: float = 1.0
var _walkable_tiles: Array = []
var _walkable := {}  ## Dictionary for quick lookups of walkable tiles.
var _discovered := {}  ## Tiles that have been revealed by the player.


func _ready() -> void:
	if player_path != NodePath():
		_player = get_node_or_null(player_path)
	else:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			_player = players[0] as Node3D
	get_tree().connect("node_added", Callable(self, "_on_node_added"))
	get_tree().connect("node_removed", Callable(self, "_on_node_removed"))
	print("minimap ready!")


func _on_node_added(node: Node) -> void:
	if node.name == "GeneratedLevel" and node is Node3D:
		print("Level generated")
		_set_level(node)
		print("Level set for minimap!!!!!!")


func _on_node_removed(node: Node) -> void:
	if node == _level:
		_level = null
		_walkable_tiles.clear()
		_walkable.clear()
		_level_size = Vector2i.ZERO
		_discovered.clear()
		queue_redraw()


func _set_level(level: Node3D) -> void:
	print("SETTING LEVEL")
	_level = level
	_walkable_tiles = level.get_meta("walkable_tiles", [])
	_walkable.clear()
	for p in _walkable_tiles:
			_walkable[p] = true
	_level_size = level.get_meta("level_size", Vector2i.ZERO)
	_tile_size = level.get_meta("tile_size", 1.0)
	_discovered.clear()

	# The minimap itself is transparent, so we simply size the Control.
	custom_minimum_size = Vector2(_level_size) * map_scale
	queue_redraw()


func _process(_delta: float) -> void:
	if not _player or not _level:
		return
	var tile := Vector2i(
			int(floor(_player.global_position.x / _tile_size)),
			int(floor(_player.global_position.z / _tile_size))
	)
	var radius_sq := reveal_radius * reveal_radius
	for x in range(tile.x - reveal_radius, tile.x + reveal_radius + 1):
			for y in range(tile.y - reveal_radius, tile.y + reveal_radius + 1):
					var p := Vector2i(x, y)
					var d := p - tile
					if d.length_squared() > radius_sq:
							continue
					if _walkable.has(p) and not _discovered.has(p):
							_reveal(p)
	queue_redraw()


func _reveal(tile: Vector2i) -> void:
	"""Marks a tile as explored so its walls and contents remain visible."""
	_discovered[tile] = true


func _draw() -> void:
		if _level_size == Vector2i.ZERO:
				return

		# Draw discovered wall segments.
		var thickness = max(1.0, map_scale * 0.1)
		for tile in _discovered.keys():
				var base := Vector2(tile) * map_scale
				var neighbors := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
				for dir in neighbors:
						var ntile = tile + dir
						var out_of_bounds = ntile.x < 0 or ntile.y < 0 or ntile.x >= _level_size.x or ntile.y >= _level_size.y
						if out_of_bounds or not _walkable.has(ntile):
								match dir:
										Vector2i.UP:
												draw_line(base, base + Vector2(map_scale, 0), wall_color, thickness)
										Vector2i.DOWN:
												draw_line(
														base + Vector2(0, map_scale),
														base + Vector2(map_scale, map_scale),
														wall_color,
														thickness
												)
										Vector2i.LEFT:
												draw_line(base, base + Vector2(0, map_scale), wall_color, thickness)
										Vector2i.RIGHT:
												draw_line(
														base + Vector2(map_scale, 0),
														base + Vector2(map_scale, map_scale),
														wall_color,
														thickness
												)

		# Draw the player icon.
		if _player:
				var p := (
						Vector2(_player.global_position.x / _tile_size, _player.global_position.z / _tile_size)
						* map_scale
				)
				draw_circle(p + Vector2(map_scale * 0.5, map_scale * 0.5), map_scale * 0.3, player_color)

		# Draw visible enemies and bosses.
		if _level:
				var enemies = _level.get_tree().get_nodes_in_group("enemy")
				for e in enemies:
						if not (e is Node3D):
								continue
						if (
								_player
								and (
										(e as Node3D).global_position.distance_to(_player.global_position)
										> enemy_reveal_distance
								)
						):
								continue
						var etile := Vector2i(
								int(floor((e as Node3D).global_position.x / _tile_size)),
								int(floor((e as Node3D).global_position.z / _tile_size))
						)
						if not _discovered.has(etile):
								continue
						var color := enemy_color
						if "tier" in e and e.tier == e.Tier.BOSS:
								color = boss_color
						var pos := Vector2(etile) * map_scale + Vector2(map_scale * 0.5, map_scale * 0.5)
						draw_circle(pos, map_scale * 0.3, color)
