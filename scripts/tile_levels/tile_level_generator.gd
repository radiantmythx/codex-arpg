class_name TileLevelGenerator
extends RefCounted

# Procedurally builds a scene composed of room tiles and connecting tunnels.
# The generator operates purely in code so it can run at edit time or runtime.
#
# The generator now also places a `PlayerSpawn` marker in the first room,
# optionally instantiates a boss in the farthest room and can populate any
# interior tiles with enemies supplied via `TileLevelSettings`.

const DIRS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

func generate(settings: TileLevelSettings) -> Node3D:
	"""
	Builds the level layout and populates it with optional spawn markers,
	enemies and a boss. All coordinates are kept within
	`settings.level_size`.
	"""
	print("Starting tile generator...")
	var rng := RandomNumberGenerator.new()
	if settings.seed != 0:
			rng.seed = settings.seed
	else:
			rng.randomize()
	print("Seed: ", rng)
	var tiles := {}
	var rooms: Array[Rect2i] = []
	for i in range(settings.room_count):
			var size_x = rng.randi_range(settings.room_min_size.x, settings.room_max_size.x)
			var size_y = rng.randi_range(settings.room_min_size.y, settings.room_max_size.y)
			var pos_x = rng.randi_range(0, max(0, settings.level_size.x - size_x))
			var pos_y = rng.randi_range(0, max(0, settings.level_size.y - size_y))
			var rect := Rect2i(pos_x, pos_y, size_x, size_y)
			rooms.append(rect)
			_fill_rect(rect, tiles, settings.level_size)
	
	print(settings.room_count, " rooms filled")
	
	var width := _tunnel_width(settings.tunnel_size)
	for i in range(1, rooms.size()):
			var a := _rect_center(rooms[i - 1])
			var b := _rect_center(rooms[i])
			_dig_corridor(a, b, width, tiles, settings.level_size)

	print("Corridors created")

	if settings.obstacle_chance > 0.0:
			_add_obstacles(tiles, settings.obstacle_chance, rng)
			_ensure_connected(tiles)

	print("Obstacles added, connections ensured")

	var root := Node3D.new()
	var default_positions: Array[Vector2i] = []
	var outside_rects: Array[Rect2] = []
	
	print("Placing tiles...")
	
	for pos in tiles.keys():
		var scene := _select_tile_scene(pos, tiles, settings.tiles)
		if scene:
				var inst = scene.instantiate()
				inst.position = Vector3(pos.x * settings.tile_size, 0, pos.y * settings.tile_size)
				inst.name = "ground" + random_string(8)
				root.add_child(inst, true)

	if settings.draw_default_tiles and settings.default_tile:
			print("Spawning default tiles...")
			default_positions = _spawn_default_tiles(root, tiles, settings.default_tile, settings.level_size, settings.tile_size)
	if settings.draw_default_tiles_outside_level and settings.default_tile:
			print("Spawning default tiles outside of level...")
			outside_rects = _spawn_outside_default_tiles(root, settings.default_tile, settings.level_size, settings.tile_size, settings.default_tile_outside_scale)
	print("Spawning default decorations...")
	_spawn_default_decorations(root, default_positions, outside_rects, settings.default_decorations, rng, settings.tile_size)
	print("Spawning decorations...")
	_spawn_decorations(root, tiles, settings.decorations, rng, settings.tile_size)

	# Determine spawn locations using room centers.
	var start_room := rooms[0]
	var player_pos := _rect_center(start_room)
	var furthest_room := start_room
	var max_dist := 0.0
	for room in rooms:
			var dist = player_pos.distance_to(_rect_center(room))
			if dist > max_dist:
					max_dist = dist
					furthest_room = room
	var boss_pos := _rect_center(furthest_room)
	
	print("Added player and boss spawn positions...")

	# Player spawn marker.
	var player_spawn := Node3D.new()
	player_spawn.name = "PlayerSpawn"
	player_spawn.position = Vector3(player_pos.x * settings.tile_size, 0, player_pos.y * settings.tile_size)
	root.add_child(player_spawn)

	# Boss spawn or marker.
	if settings.boss_scene:
			var boss = settings.boss_scene.instantiate()
			boss.position = Vector3(boss_pos.x * settings.tile_size, 0, boss_pos.y * settings.tile_size)
			root.add_child(boss)
			print("Added boss scene")
	else:
			var boss_spawn := Node3D.new()
			boss_spawn.name = "BossSpawn"
			boss_spawn.position = Vector3(boss_pos.x * settings.tile_size, 0, boss_pos.y * settings.tile_size)
			root.add_child(boss_spawn)
	
	# Enemy population. Only spawn on center tiles to keep within bounds.
	if settings.enemy_density > 0.0 and not settings.enemy_scenes.is_empty():
			print("Spawning enemies")
			for pos in tiles.keys():
					if pos == player_pos or pos == boss_pos:
							continue
					if _is_center_tile(pos, tiles) and rng.randf() < settings.enemy_density:
							var scene: PackedScene = settings.enemy_scenes[rng.randi_range(0, settings.enemy_scenes.size() - 1)]
							if scene:
									var enemy = scene.instantiate()
									enemy.position = Vector3(pos.x * settings.tile_size, 0, pos.y * settings.tile_size)
									root.add_child(enemy, true)

	return root

func random_string(length: int = 8) -> String:
	var chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var result = ""
	for i in length:
		result += chars[randi() % chars.length()]
	return result

func _fill_rect(rect: Rect2i, tiles: Dictionary, bounds: Vector2i) -> void:
		for x in range(rect.position.x, rect.position.x + rect.size.x):
				for y in range(rect.position.y, rect.position.y + rect.size.y):
						var p := Vector2i(x, y)
						if _in_bounds(p, bounds):
								tiles[p] = true

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

func _dig_corridor(a: Vector2i, b: Vector2i, width: int, tiles: Dictionary, bounds: Vector2i) -> void:
		if width <= 0:
				return
		var dir_x = 1 if b.x > a.x else -1
		for x in range(a.x, b.x + dir_x, dir_x):
				for w in range(-width / 2, width / 2 + 1):
						var p := Vector2i(x, a.y + w)
						if _in_bounds(p, bounds):
								tiles[p] = true
		var dir_y = 1 if b.y > a.y else -1
		for y in range(a.y, b.y + dir_y, dir_y):
				for w in range(-width / 2, width / 2 + 1):
						var p2 := Vector2i(b.x + w, y)
						if _in_bounds(p2, bounds):
								tiles[p2] = true

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


func _spawn_default_tiles(parent: Node3D, tiles: Dictionary, scene: PackedScene, level_size: Vector2i, tile_size: float) -> Array[Vector2i]:
		var positions: Array[Vector2i] = []
		for x in range(level_size.x):
				for y in range(level_size.y):
						var p := Vector2i(x, y)
						if tiles.has(p):
								continue
						var inst = scene.instantiate()
						inst.position = Vector3(x * tile_size, 0, y * tile_size)
						parent.add_child(inst, true)
						positions.append(p)
		return positions

func _spawn_outside_default_tiles(parent: Node3D, scene: PackedScene, level_size: Vector2i, tile_size: float, scale_factor: float) -> Array[Rect2]:
		var rects: Array[Rect2] = []
		var w = level_size.x * tile_size
		var h = level_size.y * tile_size
		var sx = level_size.x * scale_factor
		var sz = level_size.y * scale_factor
		var half_w_scaled = sx * tile_size / 2
		var half_h_scaled = sz * tile_size / 2
		var half_w = w / 2
		var half_h = h / 2
		var centers = [
				Vector3(-half_w_scaled - half_w, 0, half_h),
				Vector3(w + half_w_scaled + half_w, 0, half_h),
				Vector3(half_w, 0, -half_h_scaled - half_h),
				Vector3(half_w, 0, h + half_h_scaled + half_h),
				Vector3(-half_w_scaled - half_w, 0, -half_h_scaled - half_h),
				Vector3(w + half_w_scaled + half_w, 0, -half_h_scaled - half_h),
				Vector3(-half_w_scaled - half_w, 0, h + half_h_scaled + half_h),
				Vector3(w + half_w_scaled + half_w, 0, h + half_h_scaled + half_h)
		]
		for c in centers:
				var inst = scene.instantiate()
				inst.position = c
				inst.scale = Vector3(sx, 1, sz)
				parent.add_child(inst, true)
				rects.append(Rect2(c.x - half_w_scaled, c.z - half_h_scaled, sx * tile_size, sz * tile_size))
		return rects

func _spawn_default_decorations(parent: Node3D, tile_positions: Array[Vector2i], outside_rects: Array[Rect2], decos: Array[DefaultTileDecoration], rng: RandomNumberGenerator, tile_size: float) -> void:
		if decos.is_empty():
				return
		for deco in decos:
				if deco.mesh == null or deco.frequency <= 0.0:
						continue
				var transforms: Array[Transform3D] = []
				for p in tile_positions:
						if rng.randf() < deco.frequency:
								var offset = Vector3((p.x + rng.randf()) * tile_size, 0, (p.y + rng.randf()) * tile_size)
								transforms.append(Transform3D(Basis(), offset))
				for rect in outside_rects:
						var cells_x = int(rect.size.x / tile_size)
						var cells_y = int(rect.size.y / tile_size)
						for x in range(cells_x):
								for y in range(cells_y):
										if rng.randf() < deco.frequency:
												var pos = Vector3(rect.position.x + (x + rng.randf()) * tile_size, 0, rect.position.y + (y + rng.randf()) * tile_size)
												transforms.append(Transform3D(Basis(), pos))
				if transforms.size() == 0:
						continue
				var mm = MultiMesh.new()
				mm.mesh = deco.mesh
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.instance_count = transforms.size()
				for i in range(transforms.size()):
						mm.set_instance_transform(i, transforms[i])
				var mmi = MultiMeshInstance3D.new()
				mmi.multimesh = mm
				parent.add_child(mmi, true)
# ---------------------------------------------------------------------------
# Helper functions

func _in_bounds(p: Vector2i, bounds: Vector2i) -> bool:
		return p.x >= 0 and p.y >= 0 and p.x < bounds.x and p.y < bounds.y

func _is_center_tile(pos: Vector2i, tiles: Dictionary) -> bool:
		for d in DIRS:
				if not tiles.has(pos + d):
						return false
		return true
