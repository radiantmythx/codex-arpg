extends CharacterBody3D

@export var move_speed: float = 5.0
@export var rotation_speed: float = 5.0
@export var attack_cooldown: float = 0.5
@export var attack_range: float = 2.0
@export var attack_angle: float = 45.0 # degrees

var _attack_timer: float = 0.0

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
	var attack_area = Area3D.new()
	var shape = CylinderShape3D.new()
	shape.height = 1.0
	shape.radius = attack_range
	var collider = CollisionShape3D.new()
	collider.shape = shape
	attack_area.add_child(collider)

	attack_area.transform.origin = global_transform.origin + (-global_transform.basis.z) * attack_range
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
        for body in bodies:
                if body.has_method("take_damage"):
                        body.take_damage(1)
