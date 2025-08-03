extends Skill
class_name MeleeSkill

const Buff = preload("res://scripts/buff.gd")

@export var range: float = 2.0 # Radius of the swing
@export var angle: float = 45.0
@export var on_hit_effect: PackedScene # Effect spawned on struck bodies
@export var on_hit_buff: Buff # Buff or debuff applied to bodies hit

func perform(user):
        if user == null:
                return
        var direction: Vector3
        if user.has_method("_get_click_direction"):
                direction = user._get_click_direction()
        else:
                direction = -user.global_transform.basis.z
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
        timer.wait_time = 0.1
        timer.one_shot = true
        timer.autostart = true
        timer.connect("timeout", Callable(attack_area, "queue_free"))
        attack_area.add_child(timer)
        var params = PhysicsShapeQueryParameters3D.new()
        params.shape = shape
        params.transform = attack_area.global_transform
        params.collide_with_bodies = true
        var bodies = user.get_world_3d().direct_space_state.intersect_shape(params)
        var dmg_map = user.stats.get_all_damage(tags)
        for result in bodies:
                var body = result.get("collider")
                if body and body.has_method("take_damage"):
                        if user.is_in_group("player") and body.is_in_group("enemy") or user.is_in_group("enemy") and body.is_in_group("player"):
                                for dt in dmg_map.keys():
                                        var dmg = dmg_map[dt]
                                        if dmg > 0:
                                                body.take_damage(dmg, dt)
                                if on_hit_buff and body.has_method("add_buff"):
                                        body.add_buff(on_hit_buff)
                                if on_hit_effect:
                                        var eff = on_hit_effect.instantiate()
                                        body.add_child(eff)
