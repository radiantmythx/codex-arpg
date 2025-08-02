extends CharacterBody3D

@export var max_health: int = 3
@export var move_speed: float = 2.0
@export var wander_speed: float = 1.0
@export var wander_change_interval: float = 2.0
@export var detection_range: float = 8.0
@export var attack_range: float = 1.5
@export var attack_windup: float = 0.5
@export var attack_cooldown: float = 1.0
@export var healthbar_node_path: NodePath

## Drop table is an array of dictionaries like:
## {"item": Item, "chance": 0.5, "amount": 1}
@export var drop_table: Array = []

var current_health: int

signal died

var _player: Node3D
var _wander_timer: float = 0.0
var _current_dir: Vector3 = Vector3.ZERO
var _attack_timer: float = 0.0
var _windup_timer: float = 0.0
var _mesh: MeshInstance3D
var _original_material: Material
var _healthbar: Healthbar

func _ready() -> void:
	randomize()
	add_to_group("enemy")
	current_health = max_health
	_player = get_tree().get_root().find_child("Player", true, false)
	_mesh = get_node_or_null("MeshInstance3D")
	if _mesh:
		_original_material = _mesh.material_override
	if healthbar_node_path != NodePath():
			_healthbar = get_node(healthbar_node_path)
			if(_healthbar):
				_healthbar.set_health(current_health, max_health)

func _physics_process(delta: float) -> void:
	_process_timers(delta)
	if _windup_timer > 0.0:
		return
	var player_pos := _get_player_position()
	if player_pos and global_transform.origin.distance_to(player_pos) <= attack_range and _attack_timer <= 0.0:
		_start_windup()
	elif player_pos and global_transform.origin.distance_to(player_pos) <= detection_range:
		_chase(player_pos, delta)
	else:
		_wander(delta)

func _process_timers(delta: float) -> void:
	if _attack_timer > 0.0:
		_attack_timer -= delta
	if _windup_timer > 0.0:
		_windup_timer -= delta
		if _windup_timer <= 0.0:
			_perform_attack()

func _wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = wander_change_interval
		_current_dir = Vector3(randf() * 2.0 - 1.0, 0, randf() * 2.0 - 1.0).normalized()
	if _current_dir != Vector3.ZERO:
		var target_rot := Transform3D().looking_at(_current_dir, Vector3.UP).basis.get_euler().y
		rotation.y = lerp_angle(rotation.y, target_rot, 5.0 * delta)
	velocity = _current_dir * wander_speed
	move_and_slide()

func _chase(player_pos: Vector3, delta: float) -> void:
	var dir := (player_pos - global_transform.origin).normalized()
	var target_rot := Transform3D().looking_at(dir, Vector3.UP).basis.get_euler().y
	rotation.y = lerp_angle(rotation.y, target_rot, 5.0 * delta)
	velocity = dir * move_speed
	move_and_slide()

func _start_windup() -> void:
	#print("Winding up!")
	_windup_timer = attack_windup
	if _mesh:
		_mesh.material_override = StandardMaterial3D.new()
		_mesh.material_override.albedo_color = Color(1, 0, 0, 1)

func _perform_attack() -> void:
	if _mesh:
		_mesh.material_override = _original_material
		_attack_timer = attack_cooldown
		var shape := CapsuleShape3D.new()
		shape.radius = attack_range
		shape.height = 1.0
		var area := Area3D.new()
		var collider := CollisionShape3D.new()
		var mesh = MeshInstance3D.new()
		mesh.mesh = CylinderMesh.new()
		mesh.mesh.top_radius = attack_range
		mesh.mesh.bottom_radius = attack_range
		mesh.mesh.height = 1.0
		mesh.material_override = StandardMaterial3D.new()
		mesh.material_override.albedo_color = Color(1, 0, 0, 0.5)
		mesh.visible = true
		collider.shape = shape
		area.add_child(collider)
		area.add_child(mesh)
		area.transform.origin = global_transform.origin + -global_transform.basis.z * attack_range
		get_parent().add_child(area)
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = shape
		params.transform = area.global_transform
		params.collide_with_bodies = true
		var bodies := get_world_3d().direct_space_state.intersect_shape(params)
		for result in bodies:
			var body = result.get("collider")
			if body != null and body.has_method("take_damage") and body.is_in_group("players"):
				body.take_damage(1)
		await get_tree().create_timer(0.2).timeout
		area.queue_free()

func _get_player_position() -> Vector3:
	if _player and _player.is_inside_tree():
		return _player.global_transform.origin
	return Vector3()

func take_damage(amount: int) -> void:
	#print("Ow! Took ", amount)
	current_health -= amount
	if(_healthbar):
		_healthbar.set_health(current_health, max_health)
	if current_health <= 0:
		die()

func die() -> void:
	_drop_loot()
	emit_signal("died")
	queue_free()

func _drop_loot() -> void:
	var drop_scene := preload("res://scenes/item_drop.tscn")
	for entry in drop_table:
		if randf() <= float(entry.get("chance", 1.0)):
			var drop := drop_scene.instantiate()
			var area := drop.get_node_or_null("Area3D")
			print(entry)
			if area and entry.has("item"):
				#print("that being said, entry item is ", entry["item"].item_name)
				area.item = entry["item"]
			if entry.has("amount"):
				area.amount = entry["amount"]
			print("dropping item ", area.item)
			
			get_parent().add_child(drop)
			drop.global_transform.origin = global_transform.origin
