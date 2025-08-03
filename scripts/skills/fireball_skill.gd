extends Skill
class_name FireballSkill

@export var speed: float = 10.0
@export var range: float = 15.0
@export var explosion_radius: float = 2.0

func perform(user):
	if user == null:
		return
	var direction: Vector3
	if user.has_method("_get_click_direction"):
		direction = user._get_click_direction()
	else:
		direction = -user.global_transform.basis.z
	user.look_at(user.global_transform.origin + direction, Vector3.UP)
	var projectile = Area3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.2
	var collider = CollisionShape3D.new()
	collider.shape = shape
	var mesh = MeshInstance3D.new()
	mesh.mesh = SphereMesh.new()
	projectile.add_child(collider)
	projectile.add_child(mesh)
	projectile.body_entered.connect(_on_projectile_body_entered.bind(projectile, user))
	user.get_parent().add_child(projectile)
	projectile.global_transform.origin = user.global_transform.origin + direction
	var travel_time = range / speed
	var tween = projectile.create_tween()
	tween.tween_property(projectile, "global_transform:origin", user.global_transform.origin + direction * range, travel_time)
	tween.connect("finished", Callable(self, "_on_projectile_finished").bind(projectile, user))

func _on_projectile_body_entered(body, projectile, user):
	if body and body.has_method("take_damage"):
		if user.is_in_group("player") and body.is_in_group("enemy") or user.is_in_group("enemy") and body.is_in_group("player"):
			var dmg_map = user.stats.get_all_damage(tags)
			var solar_base = user.stats.base_damage[Stats.DamageType.SOLAR] + 3
			dmg_map[Stats.DamageType.SOLAR] = user.stats._compute_stat_tagged(solar_base, "solar_damage", tags)
			for dt in dmg_map.keys():
				var dmg = dmg_map[dt]
				if dmg > 0:
					body.take_damage(dmg, dt)
	_explode(projectile.global_transform.origin, user)
	projectile.queue_free()

func _on_projectile_finished(projectile, user):
	#_explode(projectile.global_transform.origin, user)
	projectile.queue_free()

func _explode(origin: Vector3, user):
	var shape = SphereShape3D.new()
	shape.radius = explosion_radius
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), origin)
	params.collide_with_bodies = true
	var bodies = user.get_world_3d().direct_space_state.intersect_shape(params)
	var solar_base = user.stats.base_damage[Stats.DamageType.SOLAR] + 1
	var dmg = user.stats._compute_stat_tagged(solar_base, "solar_damage", tags)
	for result in bodies:
		var body = result.get("collider")
		if body and body.has_method("take_damage"):
			if user.is_in_group("player") and body.is_in_group("enemy"):
				body.take_damage(dmg, Stats.DamageType.SOLAR)
			if user.is_in_group("enemy") and body.is_in_group("player"):
				body.take_damage(dmg, Stats.DamageType.SOLAR)
