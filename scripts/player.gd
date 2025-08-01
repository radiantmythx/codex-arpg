extends CharacterBody3D

@export var move_speed: float = 5.0
@export var rotation_speed: float = 5.0
@export var attack_cooldown: float = 0.5
@export var attack_range: float = 2.0
@export var attack_angle: float = 45.0 # degrees
@export var attack_duration: float = 0.2
@export var attack_move_multiplier: float = 0.2

var _attack_timer: float = 0.0
var _attacking_timer: float = 0.0
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
        var speed := move_speed
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
                var body := result.get("collider")
                if body != null and body.has_method("take_damage"):
                        body.take_damage(1)

func add_item(item: Item, amount: int = 1) -> void:
	inventory.add_item(item, amount)
