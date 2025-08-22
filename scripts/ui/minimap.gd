class_name Minimap
extends Control
"""
Renders a 2D minimap of the current procedurally generated level with a
simple fog-of-war system. The map reveals walkable tiles as the player
moves and overlays icons for nearby enemies and the boss once discovered.
Attach this script to a Control node. Set its size/anchors in the editor.
"""

@export var player_path: NodePath  ## Path to the player Node3D.
@export var map_scale: float = 4.0  ## Pixel size for each tile on the map.
@export var enemy_reveal_distance: float = 30.0  ## World units to show enemies.
@export var tile_color: Color = Color(1, 1, 1)
@export var player_color: Color = Color(0.2, 0.6, 1)
@export var enemy_color: Color = Color(1, 0, 0)
@export var boss_color: Color = Color(1, 0, 1)

var _player: Node3D
var _level: Node3D
var _level_size: Vector2i = Vector2i.ZERO
var _tile_size: float = 1.0
var _walkable_tiles: Array[Vector2i] = []
var _discovered := {}
var _map_tex: Texture2D
var _fog_image: Image
var _fog_tex: Texture2D


func _ready() -> void:
	if player_path != NodePath():
		_player = get_node_or_null(player_path)
	else:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			_player = players[0] as Node3D
	get_tree().connect("node_added", Callable(self, "_on_node_added"))
	get_tree().connect("node_removed", Callable(self, "_on_node_removed"))


func _on_node_added(node: Node) -> void:
	if node.name == "GeneratedLevel" and node is Node3D:
		_set_level(node)


func _on_node_removed(node: Node) -> void:
	if node == _level:
		_level = null
		_walkable_tiles.clear()
		_level_size = Vector2i.ZERO
		_discovered.clear()
		queue_redraw()


func _set_level(level: Node3D) -> void:
	_level = level
	_walkable_tiles = level.get_meta("walkable_tiles", [])
	_level_size = level.get_meta("level_size", Vector2i.ZERO)
	_tile_size = level.get_meta("tile_size", 1.0)
	_discovered.clear()

	var img := Image.create(_level_size.x, _level_size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for p in _walkable_tiles:
		img.set_pixelv(p, tile_color)
	_map_tex = ImageTexture.create_from_image(img)

	_fog_image = Image.create(_level_size.x, _level_size.y, false, Image.FORMAT_RGBA8)
	_fog_image.fill(Color.BLACK)
	_fog_tex = ImageTexture.create_from_image(_fog_image)

	custom_minimum_size = Vector2(_level_size) * map_scale
	queue_redraw()


func _process(_delta: float) -> void:
	if not _player or not _level:
		return
	var tile := Vector2i(
		int(floor(_player.global_position.x / _tile_size)),
		int(floor(_player.global_position.z / _tile_size))
	)
	if _walkable_tiles.has(tile) and not _discovered.has(tile):
		_reveal(tile)
	queue_redraw()


func _reveal(tile: Vector2i) -> void:
	_discovered[tile] = true
	_fog_image.set_pixelv(tile, Color(0, 0, 0, 0))
	_fog_tex.update(_fog_image)


func _draw() -> void:
	if _level_size == Vector2i.ZERO:
		return
	var rect := Rect2(Vector2.ZERO, Vector2(_level_size) * map_scale)
	draw_texture_rect(_map_tex, rect, false)
	draw_texture_rect(_fog_tex, rect, false)

	if _player:
		var p := (
			Vector2(_player.global_position.x / _tile_size, _player.global_position.z / _tile_size)
			* map_scale
		)
		draw_circle(p + Vector2(map_scale * 0.5, map_scale * 0.5), map_scale * 0.3, player_color)
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
