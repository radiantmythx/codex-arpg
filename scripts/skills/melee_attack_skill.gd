extends Skill
class_name MeleeAttackSkill

@export var range: float = 2.0
@export var angle: float = 45.0

func perform(user):
        if user == null:
                return
        var direction = user._get_click_direction()
        user.look_at(user.global_transform.origin + direction, Vector3.UP)
        var attack_area = Area3D.new()
        var shape = CylinderShape3D.new()
        shape.height = 1.0
        shape.radius = range
        var collider = CollisionShape3D.new()
        collider.shape = shape
        attack_area.add_child(collider)
        attack_area.transform.origin = user.global_transform.origin + direction * range
        user.get_parent().add_child(attack_area)
        var mesh = MeshInstance3D.new()
        mesh.mesh = CylinderMesh.new()
        mesh.mesh.top_radius = range
        mesh.mesh.bottom_radius = range
        mesh.mesh.height = 1.0
        mesh.material_override = StandardMaterial3D.new()
        mesh.material_override.albedo_color = Color(1, 0, 0, 0.5)
        mesh.visible = true
        attack_area.add_child(mesh)
        var timer = Timer.new()
        timer.wait_time = duration
        timer.one_shot = true
        timer.autostart = true
        timer.connect("timeout", Callable(attack_area, "queue_free"))
        attack_area.add_child(timer)
        var params = PhysicsShapeQueryParameters3D.new()
        params.shape = shape
        params.transform = attack_area.global_transform
        params.collide_with_bodies = true
        var bodies = user.get_world_3d().direct_space_state.intersect_shape(params)
        for result in bodies:
                var body = result.get("collider")
                if body and body.has_method("take_damage") and body.is_in_group("enemy"):
                        body.take_damage(user.stats.get_damage(damage_type), damage_type)
