extends Skill
class_name ProjectileSkill

@export var speed: float = 10.0
@export var range: float = 15.0
@export var explosion_radius: float = 0.0
@export var projectile_scene: PackedScene # Scene for projectile; placeholder sphere used if null
@export var on_hit_effect: PackedScene # Effect spawned on bodies struck
@export var explosion_effect: PackedScene # Effect placed at explosion center
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
	var projectile = _create_projectile()
	   # Snapshot all values needed so the projectile can resolve damage even if the user dies
	var base_dict = _build_base_damage_dict(user)
	var dmg_map = user.stats.compute_damage(base_dict, tags)
	var buff_snapshot
	if on_hit_buff:
			buff_snapshot = on_hit_buff.duplicate(true)
			if buff_snapshot is DamageOverTimeBuff:
					var dot_dict = {buff_snapshot.damage_type: Vector2(buff_snapshot.base_damage_low, buff_snapshot.base_damage_high)}
					var dot_map = user.stats.compute_damage(dot_dict, tags)
					buff_snapshot.damage_per_second = dot_map[buff_snapshot.damage_type]
	projectile.set_meta("dmg_map", dmg_map)
	projectile.set_meta("buff_snapshot", buff_snapshot)
	projectile.set_meta("aoe_mult", user.stats.get_aoe_multiplier())
	projectile.set_meta("is_player", user.is_in_group("player"))
	projectile.body_entered.connect(_on_projectile_body_entered.bind(projectile))
	user.get_parent().add_child(projectile)
	projectile.global_transform.origin = user.global_transform.origin + direction
	projectile.position.y += 2
	var travel_time = range / speed
	var tween = projectile.create_tween()
	tween.tween_property(projectile, "global_transform:origin", user.global_transform.origin + direction * range, travel_time)
	tween.connect("finished", Callable(self, "_on_projectile_finished").bind(projectile))

func _create_projectile():
	if projectile_scene:
		return projectile_scene.instantiate()
	var p = Area3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.2
	var collider = CollisionShape3D.new()
	collider.shape = shape
	p.add_child(collider)
	var mesh = MeshInstance3D.new()
	mesh.mesh = SphereMesh.new()
	p.add_child(mesh)
	return p

func _on_projectile_body_entered(body, projectile):
	if body and body.has_method("take_damage"):
			var is_player = projectile.get_meta("is_player")
			if (is_player and body.is_in_group("enemy")) or (not is_player and body.is_in_group("player")):
					var dmg_map = projectile.get_meta("dmg_map")
					for dt in dmg_map.keys():
							var dmg = dmg_map[dt]
							if dmg > 0:
									body.take_damage(dmg, dt)
					var buff_snapshot = projectile.get_meta("buff_snapshot")
					if buff_snapshot and body.has_method("add_buff"):
							body.add_buff(buff_snapshot.duplicate(true))
					if on_hit_effect:
						var eff = on_hit_effect.instantiate()
						eff.global_transform = body.global_transform
						body.get_tree().current_scene.add_child(eff)
						body.add_child(eff)
	_explode(projectile)
	projectile.queue_free()

func _on_projectile_finished(projectile):
	_explode(projectile)
	projectile.queue_free()

func _explode(projectile):
	var origin = projectile.global_transform.origin
	if explosion_radius <= 0.0:
			if explosion_effect:
					var eff = explosion_effect.instantiate()
					eff.global_transform.origin = origin
					projectile.get_parent().add_child(eff)
			return
	var mult = projectile.get_meta("aoe_mult")
	var shape = SphereShape3D.new()
	shape.radius = explosion_radius * mult
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), origin)
	params.collide_with_bodies = true
	var bodies = projectile.get_world_3d().direct_space_state.intersect_shape(params)
	var dmg_map = projectile.get_meta("dmg_map")
	var buff_snapshot = projectile.get_meta("buff_snapshot")
	var is_player = projectile.get_meta("is_player")
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
			e.scale = Vector3.ONE * explosion_radius * mult
			projectile.get_parent().add_child(e)
