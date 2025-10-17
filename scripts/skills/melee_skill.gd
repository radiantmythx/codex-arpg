extends Skill
class_name MeleeSkill

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
	var attack_area := Area3D.new()
	var shape := CylinderShape3D.new()
	shape.height = 1.0
	shape.radius = range

	var collider := CollisionShape3D.new()
	collider.shape = shape
	attack_area.add_child(collider)

	attack_area.position = user.position + direction * range
	user.get_parent().add_child(attack_area)

	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = range
	cyl.bottom_radius = range
	cyl.height = 0.1
	cyl.radial_segments = 32
	mesh_inst.mesh = cyl
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	attack_area.add_child(mesh_inst)

	# Use the saved material
	var mat_res := preload("res://materials/attack_woosh.tres")
	mat_res.resource_local_to_scene = true
	mesh_inst.material_override = mat_res

	# Per-instance shader params (requires "instance uniform" in shader)
	mesh_inst.set_instance_shader_parameter("fade", 1.0)
	mesh_inst.set_instance_shader_parameter("woosh_pulse", 0.0)

	# Animate pulse + fade
	var tw := attack_area.create_tween().set_parallel(true)
	tw.tween_method(func(v): mesh_inst.set_instance_shader_parameter("woosh_pulse", v), 0.0, 1.0, 0.08)
	tw.tween_interval(0.02)
	tw.tween_method(func(v): mesh_inst.set_instance_shader_parameter("woosh_pulse", v), 1.0, 0.0, 0.12)
	tw.tween_method(func(v): mesh_inst.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.5)
	tw.connect("finished", Callable(attack_area, "queue_free"))

	# Physics query unchanged
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = attack_area.global_transform
	params.collide_with_bodies = true
	var bodies = user.get_world_3d().direct_space_state.intersect_shape(params)

	var base_dict = _build_base_damage_dict(user)
	var dmg_map = user.stats.compute_damage(base_dict, tags)
	var buff_snapshot
	if on_hit_buff:
			buff_snapshot = on_hit_buff.duplicate(true)
			if buff_snapshot is DamageOverTimeBuff:
					var dot_dict = {buff_snapshot.damage_type: Vector2(buff_snapshot.base_damage_low, buff_snapshot.base_damage_high)}
					var dot_map = user.stats.compute_damage(dot_dict, tags)
					buff_snapshot.damage_per_second = dot_map[buff_snapshot.damage_type]
	var is_player = user.is_in_group("player")
	for result in bodies:
			var body = result.get("collider")
			if body and body.has_method("take_damage"):
					if (is_player and body.is_in_group("enemy")) or (not is_player and body.is_in_group("player")):
							for dt in dmg_map.keys():
									var dmg = dmg_map[dt]
									if dmg > 0:
											body.take_damage(dmg, dt)
							if buff_snapshot and body.has_method("add_buff"):
									body.add_buff(buff_snapshot.duplicate(true))
							if on_hit_effect:
									var eff = on_hit_effect.instantiate()
									eff.global_transform = body.global_transform
									eff.position.y += 2
									body.get_tree().current_scene.add_child(eff)
