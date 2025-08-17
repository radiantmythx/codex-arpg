class_name TileLevelGenerator
extends RefCounted

# Procedurally builds a scene composed of room tiles and connecting tunnels.
# The generator operates purely in code so it can run at edit time or runtime.

const DIRS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

func generate(settings: TileLevelSettings) -> Node3D:
	print("generating")
	var rng := RandomNumberGenerator.new()
	if settings.seed != 0:
		rng.seed = settings.seed
	else:
		rng.randomize()

	var tiles := {}
	var rooms: Array[Rect2i] = []
	for i in range(settings.room_count):
		var size_x = rng.randi_range(settings.room_min_size.x, settings.room_max_size.x)
		var size_y = rng.randi_range(settings.room_min_size.y, settings.room_max_size.y)
		var pos_x
		var pos_y
		if i == 0 or _tunnel_width(settings.tunnel_size) > 0:
			pos_x = rng.randi_range(-50, 50)
			pos_y = rng.randi_range(-50, 50)
		else:
			var prev: Rect2i = rooms[i - 1]
			pos_x = prev.position.x + prev.size.x
			pos_y = prev.position.y
		var rect := Rect2i(pos_x, pos_y, size_x, size_y)
		rooms.append(rect)
		_fill_rect(rect, tiles)

	var width := _tunnel_width(settings.tunnel_size)
	for i in range(1, rooms.size()):
		var a := _rect_center(rooms[i - 1])
		var b := _rect_center(rooms[i])
		_dig_corridor(a, b, width, tiles)

	if settings.obstacle_chance > 0.0:
		_add_obstacles(tiles, settings.obstacle_chance, rng)
		_ensure_connected(tiles)

	var root := Node3D.new()
	for pos in tiles.keys():
		var scene := _select_tile_scene(pos, tiles, settings.tiles)
		if scene:
			var inst = scene.instantiate()
			inst.position = Vector3(pos.x * settings.tile_size, 0, pos.y * settings.tile_size)
			inst.name = "ground"+random_string(8)
			root.add_child(inst)

	_spawn_decorations(root, tiles, settings.decorations, rng, settings.tile_size)
	print(root)
	print(root.get_child_count())
	return root

func random_string(length: int = 8) -> String:
	var chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var result = ""
	for i in length:
		result += chars[randi() % chars.length()]
	return result

func _fill_rect(rect: Rect2i, tiles: Dictionary) -> void:
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			tiles[Vector2i(x, y)] = true

func _rect_center(rect: Rect2i) -> Vector2i:
	return Vector2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)

func _tunnel_width(size: int) -> int:
	match size:
		TileLevelSettings.TunnelSize.EXTRA_SMALL:
			return 1
		TileLevelSettings.TunnelSize.SMALL:
			return 2
		TileLevelSettings.TunnelSize.MEDIUM:
			return 3
		TileLevelSettings.TunnelSize.LARGE:
			return 4
		TileLevelSettings.TunnelSize.EXTRA_LARGE:
			return 5
		TileLevelSettings.TunnelSize.GIGANTIC:
			return 6
		_:
			return 0

func _dig_corridor(a: Vector2i, b: Vector2i, width: int, tiles: Dictionary) -> void:
	if width <= 0:
		return
	var dir_x = 1 if b.x > a.x else -1
	for x in range(a.x, b.x + dir_x, dir_x):
		for w in range(-width / 2, width / 2 + 1):
			tiles[Vector2i(x, a.y + w)] = true
	var dir_y = 1 if b.y > a.y else -1
	for y in range(a.y, b.y + dir_y, dir_y):
		for w in range(-width / 2, width / 2 + 1):
			tiles[Vector2i(b.x + w, y)] = true

func _add_obstacles(tiles: Dictionary, chance: float, rng: RandomNumberGenerator) -> void:
	var to_remove: Array[Vector2i] = []
	for pos in tiles.keys():
		if rng.randf() < chance:
			to_remove.append(pos)
	for pos in to_remove:
		tiles.erase(pos)

func _ensure_connected(tiles: Dictionary) -> void:
	if tiles.is_empty():
		return
	var start = tiles.keys()[0]
	var queue: Array[Vector2i] = [start]
	var visited := {start: true}
	while queue.size() > 0:
		var p = queue.pop_front()
		for d in DIRS:
			var np = p + d
			if tiles.has(np) and not visited.has(np):
				visited[np] = true
				queue.append(np)
	for pos in tiles.keys():
		if not visited.has(pos):
			tiles.erase(pos)

func _select_tile_scene(pos: Vector2i, tiles: Dictionary, set: Tile9Set) -> PackedScene:
	var n = tiles.has(pos + Vector2i(0, -1))
	var s = tiles.has(pos + Vector2i(0, 1))
	var e = tiles.has(pos + Vector2i(1, 0))
	var w = tiles.has(pos + Vector2i(-1, 0))
	if not n and not w:
		return set.corner_nw
	if not n and not e:
		return set.corner_ne
	if not s and not w:
		return set.corner_sw
	if not s and not e:
		return set.corner_se
	if not n:
		return set.edge_n
	if not s:
		return set.edge_s
	if not e:
		return set.edge_e
	if not w:
		return set.edge_w
	return set.center

func _spawn_decorations(parent: Node3D, tiles: Dictionary, decos: Array[LevelDecoration], rng: RandomNumberGenerator, tile_size: float) -> void:
	if decos.is_empty():
		return
	for pos in tiles.keys():
		for deco in decos:
			if deco.scene and rng.randf() < deco.frequency:
				var inst = deco.scene.instantiate()
				inst.position = Vector3(pos.x * tile_size, 0, pos.y * tile_size)
				parent.add_child(inst)
