extends CharacterBody3D

@export var move_speed: float = 5.0
@export var rotation_speed: float = 5.0
@export var attack_cooldown: float = 0.5
@export var attack_range: float = 2.0
@export var attack_angle: float = 45.0 # degrees

var _attack_timer: float = 0.0
var inventory := Inventory.new()

func _ready() -> void:
	add_child(inventory)

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
	_process_movement(delta)
	_process_attack(delta)

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
	velocity = input_dir * move_speed
	move_and_slide()

func _process_attack(delta: float) -> void:
	if _attack_timer > 0.0:
		_attack_timer -= delta

	if Input.is_action_just_pressed("attack") and _attack_timer <= 0.0:
		_attack_timer = attack_cooldown
		perform_attack()

func perform_attack() -> void:
	var direction := _get_click_direction()
	look_at(global_transform.origin + direction, Vector3.UP)
	var attack_area = Area3D.new()
	var shape = CylinderShape3D.new()
	shape.height = 1.0
	shape.radius = 0.75
	var collider = CollisionShape3D.new()
	collider.shape = shape
	attack_area.add_child(collider)
	
	attack_area.transform.origin = global_transform.origin + direction * attack_range
	add_child(attack_area)
	
	var mesh = MeshInstance3D.new()
	mesh.mesh = CylinderMesh.new()
	mesh.mesh.top_radius = attack_range
	mesh.mesh.bottom_radius = attack_range
	mesh.mesh.height = 0.1
	mesh.material_override = StandardMaterial3D.new()
	mesh.material_override.albedo_color = Color(1, 0, 0, 0.5)
	mesh.visible = true
	attack_area.add_child(mesh)
	
	var timer = Timer.new()
	timer.wait_time = 0.2
	timer.one_shot = true
	timer.autostart = true
	timer.connect("timeout", Callable(attack_area, "queue_free"))
	attack_area.add_child(timer)
  var bodies = attack_area.get_overlapping_bodies()
# TODO: handle damage to overlapping enemies

func add_item(item: Item, amount: int = 1) -> void:
	inventory.add_item(item, amount)
