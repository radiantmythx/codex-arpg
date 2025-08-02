extends CharacterBody3D

@export var move_speed: float = 5.0 # Base move speed before modifiers
@export var rotation_speed: float = 5.0
@export var attack_cooldown: float = 0.5
@export var attack_range: float = 2.0
@export var attack_angle: float = 45.0 # degrees
@export var attack_duration: float = 0.2
@export var attack_move_multiplier: float = 0.2
@export var inventory_ui_path: NodePath
@export var inventory_camera_path: NodePath
@export var inventory_camera_shift: float = 3.0

@export var healthbar_node_path: NodePath

# Base combat and attribute values.
@export var base_damage: float = 1.0
@export var base_defense: float = 0.0
@export var base_body: int = 0
@export var base_mind: int = 0
@export var base_soul: int = 0
@export var base_fortune: int = 0

var _attack_timer: float = 0.0
var _attacking_timer: float = 0.0
var inventory := Inventory.new()
var _inventory_ui: InventoryUI
var _camera: Camera3D
var _camera_default_pos: Vector3
var _inventory_open := false
var _healthbar: Healthbar

var health: int = 3
var max_health: int = 3

var stats: Stats
var equipment: EquipmentManager

func _ready() -> void:
	stats = Stats.new()
	stats.base_move_speed = move_speed
	stats.base_damage = base_damage
	stats.base_defense = base_defense
	stats.base_main[Stats.MainStat.BODY] = base_body
	stats.base_main[Stats.MainStat.MIND] = base_mind
	stats.base_main[Stats.MainStat.SOUL] = base_soul
	stats.base_main[Stats.MainStat.FORTUNE] = base_fortune

	equipment = EquipmentManager.new()
	equipment.stats = stats
	equipment.set_slots(["weapon", "armor"])
	add_child(equipment)

	add_child(inventory)
	if inventory_ui_path != NodePath():
		_inventory_ui = get_node(inventory_ui_path)
		if _inventory_ui:
			_inventory_ui.bind_inventory(inventory)
			_inventory_ui.bind_equipment(equipment)
	if inventory_camera_path != NodePath():
		_camera = get_node(inventory_camera_path)
		if _camera:
			_camera_default_pos = _camera.position
	if healthbar_node_path != NodePath():
		_healthbar = get_node(healthbar_node_path)
		if _healthbar:
			_healthbar.set_health(health, max_health)

	add_to_group("players")

func _get_click_direction() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return -global_transform.basis.z
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	var plane_y := global_transform.origin.y
	if abs(ray_dir.y) <= 0.0001:
		return -global_transform.basis.z
	var distance := (plane_y - ray_origin.y) / ray_dir.y
	var target := ray_origin + ray_dir * distance
	return (target - global_transform.origin).normalized()

func _physics_process(delta: float) -> void:
	_process_inventory_input()
	_process_attack(delta)
	_process_movement(delta)

func _process_movement(delta: float) -> void:
	var input_dir = Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1
	if Input.is_action_pressed("move_back"):
		input_dir.z += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	input_dir = input_dir.normalized()

	if input_dir != Vector3.ZERO:
		var target_rot = Transform3D().looking_at(input_dir, Vector3.UP).basis.get_euler().y
		rotation.y = lerp_angle(rotation.y, target_rot, rotation_speed * delta)
	var speed := stats.get_move_speed()
	if _attacking_timer > 0.0:
		speed *= attack_move_multiplier
	velocity = input_dir * speed
	move_and_slide()

func _process_attack(delta: float) -> void:
	if _attack_timer > 0.0:
		_attack_timer -= delta
	if _attacking_timer > 0.0:
		_attacking_timer -= delta

	if Input.is_action_just_pressed("attack") and _attack_timer <= 0.0:
		_attack_timer = attack_cooldown
		_attacking_timer = attack_duration
		perform_attack()

func perform_attack() -> void:
	var direction := _get_click_direction()
	look_at(global_transform.origin + direction, Vector3.UP)
	var attack_area = Area3D.new()
	var shape = CylinderShape3D.new()
	shape.height = 1.0
	shape.radius = attack_range
	var collider = CollisionShape3D.new()
	collider.shape = shape
	attack_area.add_child(collider)

	attack_area.transform.origin = global_transform.origin + direction * attack_range
	get_parent().add_child(attack_area)

	var mesh = MeshInstance3D.new()
	mesh.mesh = CylinderMesh.new()
	mesh.mesh.top_radius = attack_range
	mesh.mesh.bottom_radius = attack_range
	mesh.mesh.height = 1.0
	mesh.material_override = StandardMaterial3D.new()
	mesh.material_override.albedo_color = Color(1, 0, 0, 0.5)
	mesh.visible = true
	attack_area.add_child(mesh)

	var timer = Timer.new()
	timer.wait_time = attack_duration
	timer.one_shot = true
	timer.autostart = true
	timer.connect("timeout", Callable(attack_area, "queue_free"))
	attack_area.add_child(timer)

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = attack_area.global_transform
	params.collide_with_bodies = true

	var bodies := get_world_3d().direct_space_state.intersect_shape(params)
	for result in bodies:
		var body = result.get("collider")
		if body != null and body.has_method("take_damage") and body.is_in_group("enemy"):
			body.take_damage(stats.get_damage())

func _process_inventory_input() -> void:
	if Input.is_action_just_pressed("toggle_inventory"):
		if _inventory_open:
			close_inventory()
		else:
			open_inventory()

func open_inventory() -> void:
	_inventory_open = true
	if _inventory_ui:
		_inventory_ui.open()
	_shift_camera(true)

func close_inventory() -> void:
	_inventory_open = false
	if _inventory_ui:
		_inventory_ui.close()
	_shift_camera(false)

func _shift_camera(open: bool) -> void:
	if not _camera:
		return
	var target := _camera_default_pos
	if open:
		target.x += inventory_camera_shift
	var tween := create_tween()
	tween.tween_property(_camera, "position", target, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func add_item(item: Item, amount: int = 1) -> void:
	if _inventory_open and _inventory_ui:
		_inventory_ui.pickup_to_cursor(item, amount)
	else:
		inventory.add_item(item, amount)

func take_damage(amount) -> void:
	var actual = max(0, amount - stats.get_defense())
	health -= actual
	if _healthbar:
		_healthbar.set_health(health, max_health)
	if health <= 0:
		die()

func die():
	queue_free()
