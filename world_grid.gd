extends Node

signal level_changed(cell: Vector2i)

var current_cell: Vector2i = Vector2i.ZERO
var level_container: Node3D
var player: PlayerContainer
var _loading := false

var _warp_enabled := true

func can_accept_warp() -> bool:
	return _warp_enabled and not _loading

func _temp_disable_warp(seconds := 0.12) -> void:
	_warp_enabled = false
	get_tree().create_timer(seconds).timeout.connect(func(): _warp_enabled = true)

func _level_path(cell: Vector2i) -> String:
	return "res://scenes/gridLevels/%d_%d.tscn" % [cell.x, cell.y]
	
func set_scene_hosts(level_container_node: Node3D, player_node: Node3D) -> void:
	level_container = level_container_node
	player = player_node

func load_level(cell: Vector2i, spawn_from_dir: String = "") -> void:
	if _loading:
		return
	_loading = true
	_temp_disable_warp(0.25)  # blocks any re-entrance during load and right after
	var path := _level_path(cell)
	if not FileAccess.file_exists(path):
		print("No level found!")
		push_warning("Level missing: %s" % path)
		_loading = false
		return

	# Optional: fade out or pause input here
	# await _fade_out()

	# Clear old level
	for c in level_container.get_children():
		c.queue_free()
	await get_tree().process_frame

	# Async load to avoid hiccups
	var res := await ResourceLoader.load_threaded_request(path)
	var packed := ResourceLoader.load_threaded_get(path) if res == OK else ResourceLoader.load(path)
	var level := (packed as PackedScene).instantiate()
	level_container.add_child(level, true)

	current_cell = cell
	emit_signal("level_changed", current_cell)

	# Find spawn point based on incoming direction, default to "Spawn/Center"
	var spawn_name := "Spawn/Center"
	if spawn_from_dir != "":
		spawn_name = "Spawn/From%s" % spawn_from_dir  # From_North, From_South, etc.
	match spawn_from_dir:
		"North":
			spawn_name = "Spawn/FromSouth"
		"South":
			spawn_name = "Spawn/FromNorth"
		"East":
			spawn_name = "Spawn/FromWest"
		"West":
			spawn_name = "Spawn/FromEast"
		_:
			spawn_name = "Spawn/Center"
	print(spawn_name)
	var spawn_point := level.get_node_or_null(spawn_name)
	if not spawn_point:
		spawn_point = level.get_node_or_null("Spawn/Center")

	if not spawn_point:
		print("Couldn't find any spawns!")
	# Position player
	if player and spawn_point:
		player.global_transform = spawn_point.global_transform
		player.reset_player_position()
		#_face_player_for_entry(spawn_from_dir)

	# Optional: fade in, resume input
	# await _fade_in()
	await get_tree().physics_frame  # let transforms settle one frame
	_temp_disable_warp(0.12)        # short grace window after spawn
	_loading = false

func request_warp(offset: Vector2i, enter_from: String) -> void:
	if(!_loading):
		var target := current_cell + offset
		print("We are in ", current_cell, " and attempting to warp to ", target)
		load_level(target, enter_from)
	
func _face_player_for_entry(enter_from: String) -> void:
	if not player:
		return
	# Map "enter_from" → direction to look (toward room center)
	var dir:Vector3
	match enter_from:
		"North":
			dir = Vector3(0, 0, 1)
		"South":
			dir = Vector3(0, 0, -1)
		"East":
			dir = Vector3(-1, 0, 0)
		"West":
			dir = Vector3(1, 0, 0)
		_:
			dir = Vector3(0, 0, -1)
	# Yaw-only facing (no pitch/roll)
	if dir.length() > 0.0001:
		var yaw := atan2(dir.x, dir.z)
		var new_basis := Basis(Vector3.UP, yaw)
		# Preserve position; replace basis
		var t := player.global_transform
		t.basis = new_basis
		player.global_transform = t

# Call it after setting the player's transform in load_level():
