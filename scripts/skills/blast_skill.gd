extends Skill
class_name BlastSkill

@export var radius: float = 3.0 # Base explosion radius
@export var on_hit_effect: PackedScene # Effect spawned on struck bodies
@export var explosion_effect: PackedScene # Effect placed at blast center
@export var on_hit_buff: Buff # Buff or debuff applied to bodies hit

func perform(user):
	if user == null:
			return
	var camera = user.get_viewport().get_camera_3d()
	if camera == null:
			return
	var mouse_pos = user.get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	var plane_y = user.global_transform.origin.y
	if abs(ray_dir.y) <= 0.0001:
		return
	var distance = (plane_y - ray_origin.y) / ray_dir.y
	var target = ray_origin + ray_dir * distance
   # Snapshot values before the user might die
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
	var mult = user.stats.get_aoe_multiplier()
	var world = user.get_world_3d()
	var parent = user.get_parent()
	_explode(target, parent, world, dmg_map, buff_snapshot, mult, is_player)

func _explode(origin: Vector3, parent, world, dmg_map, buff_snapshot, mult, is_player):
	var shape = SphereShape3D.new()
	shape.radius = radius * mult
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), origin)
	params.collide_with_bodies = true
	var bodies = world.direct_space_state.intersect_shape(params)
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
									body.get_tree().current_scene.add_child(eff)

	if explosion_effect:
			var e = explosion_effect.instantiate()
			e.global_transform.origin = origin
			e.scale = Vector3.ONE * radius * mult
			parent.add_child(e)
