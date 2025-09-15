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
@export var map_rotation_degrees: float = 45.0 ## Rotate the map to match an isometric camera.
@export_range(0.0, 1.0) var map_alpha: float = 0.75: ## Overall transparency for the minimap.
		set(value):
				map_alpha = value
				if is_inside_tree():
								modulate.a = value
@export var player_icon: Texture2D ## Optional texture used instead of a circle for the player.
@export var enemy_icon: Texture2D ## Optional icon for enemies.
@export var boss_icon: Texture2D ## Optional icon for bosses.

var _player: Node3D
var _level: Node3D
var _level_size: Vector2i = Vector2i.ZERO
var _tile_size: float = 1.0
var _walkable_tiles: Array = []
var _walkable := {}  ## Dictionary for quick lookups of walkable tiles.
var _discovered := {}  ## Tiles that have been revealed by the player.
var _base_offset: Vector2 = Vector2.ZERO ## Offset applied so rotation pivots around the centre.

## Helper: returns the axis-aligned size of a rectangle after rotation.
func _rotated_size(size: Vector2, angle: float) -> Vector2:
		var cos_a = abs(cos(angle))
		var sin_a = abs(sin(angle))
		return Vector2(size.x * cos_a + size.y * sin_a, size.x * sin_a + size.y * cos_a)


func _ready() -> void:
		if player_path != NodePath():
				_player = get_node_or_null(player_path)
		else:
				var players = get_tree().get_nodes_in_group("player")
				if players.size() > 0:
						_player = players[0] as Node3D
		get_tree().connect("node_added", Callable(self, "_on_node_added"))
		get_tree().connect("node_removed", Callable(self, "_on_node_removed"))
		# Apply the requested transparency to the entire minimap Control.
		# CanvasItem.modulate is documented in Godot 4.4 under CanvasItem.
		modulate.a = map_alpha
		print("minimap ready!")


func _on_node_added(node: Node) -> void:
		# The generator always names the root "GeneratedLevel". In case something
		# slipped through with an auto-appended suffix we still accept nodes that
		# begin with the same prefix.
		if node is Node3D and node.name.begins_with("GeneratedLevel"):
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

		# Precompute values used when drawing. The map is rotated around its
		# centre so we offset all coordinates by half the unrotated size and
		# enlarge the Control to fit the rotated rectangle.
		var dims := Vector2(_level_size) * map_scale
		_base_offset = -dims / 2
		var angle := deg_to_rad(map_rotation_degrees)
		custom_minimum_size = _rotated_size(dims, angle)
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

				# Rotate all drawing around the centre so the minimap matches the
				# isometric camera. `draw_set_transform` is documented under
				# CanvasItem in Godot 4.4.
				var center := custom_minimum_size / 2
				draw_set_transform(center, deg_to_rad(map_rotation_degrees), Vector2.ONE)

				# Draw discovered wall segments.
				var thickness = max(1.0, map_scale * 0.1)
				for tile in _discovered.keys():
								var base := Vector2(tile) * map_scale + _base_offset
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

				# Draw the player icon. If a texture is supplied we draw it with
				# its centre aligned to the tile; otherwise fall back to a circle.
				if _player:
								var p := (
												Vector2(_player.global_position.x / _tile_size, _player.global_position.z / _tile_size)
												* map_scale
								) + _base_offset
								var draw_pos := p + Vector2(map_scale * 0.5, map_scale * 0.5)
								if player_icon:
												var tex_size := player_icon.get_size() / 2
												draw_texture(player_icon, draw_pos - tex_size, player_color)
								else:
												draw_circle(draw_pos, map_scale * 0.3, player_color)

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
												var tex := enemy_icon
												if "tier" in e and e.tier == e.Tier.BOSS:
																color = boss_color
																tex = boss_icon
												var pos := Vector2(etile) * map_scale + _base_offset + Vector2(map_scale * 0.5, map_scale * 0.5)
												if tex:
																var tsize := tex.get_size() / 2
																draw_texture(tex, pos - tsize, color)
												else:
																draw_circle(pos, map_scale * 0.3, color)

				# Reset transform so other UI elements are unaffected.
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
