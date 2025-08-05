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
		projectile.body_entered.connect(_on_projectile_body_entered.bind(projectile, user))
		user.get_parent().add_child(projectile)
		projectile.global_transform.origin = user.global_transform.origin + direction
		var travel_time = range / speed
		var tween = projectile.create_tween()
		tween.tween_property(projectile, "global_transform:origin", user.global_transform.origin + direction * range, travel_time)
		tween.connect("finished", Callable(self, "_on_projectile_finished").bind(projectile, user))

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

func _on_projectile_body_entered(body, projectile, user):
		if body and body.has_method("take_damage"):
                                if user.is_in_group("player") and body.is_in_group("enemy") or user.is_in_group("enemy") and body.is_in_group("player"):
                                                var base_dict = {damage_type: Vector2(base_damage_low, base_damage_high)}
                                                var dmg_map = user.stats.compute_damage(base_dict, tags)
                                                for dt in dmg_map.keys():
                                                                var dmg = dmg_map[dt]
                                                                if dmg > 0:
                                                                                body.take_damage(dmg, dt)
                                                if on_hit_buff and body.has_method("add_buff"):
                                                                var b = on_hit_buff.duplicate(true)
                                                                if b is DamageOverTimeBuff:
                                                                                var dot_dict = {b.damage_type: Vector2(b.base_damage_low, b.base_damage_high)}
                                                                                var dot_map = user.stats.compute_damage(dot_dict, tags)
                                                                                b.damage_per_second = dot_map[b.damage_type]
                                                                body.add_buff(b)
                                                if on_hit_effect:
                                                                var eff = on_hit_effect.instantiate()
                                                                body.add_child(eff)
		_explode(projectile.global_transform.origin, user)
		projectile.queue_free()

func _on_projectile_finished(projectile, user):
		_explode(projectile.global_transform.origin, user)
		projectile.queue_free()

func _explode(origin: Vector3, user):
		if explosion_radius <= 0.0:
				if explosion_effect:
						var eff = explosion_effect.instantiate()
						eff.global_transform.origin = origin
						user.get_parent().add_child(eff)
				return
		var mult = user.stats.get_aoe_multiplier()
		var shape = SphereShape3D.new()
		shape.radius = explosion_radius * mult
		var params = PhysicsShapeQueryParameters3D.new()
		params.shape = shape
		params.transform = Transform3D(Basis(), origin)
		params.collide_with_bodies = true
                var bodies = user.get_world_3d().direct_space_state.intersect_shape(params)
                var base_dict = {damage_type: Vector2(base_damage_low, base_damage_high)}
                var dmg_map = user.stats.compute_damage(base_dict, tags)
                for result in bodies:
                                var body = result.get("collider")
                                if body and body.has_method("take_damage"):
                                                if user.is_in_group("player") and body.is_in_group("enemy") or user.is_in_group("enemy") and body.is_in_group("player"):
                                                                for dt in dmg_map.keys():
                                                                                var dmg = dmg_map[dt]
                                                                                if dmg > 0:
                                                                                                body.take_damage(dmg, dt)
                                                                if on_hit_buff and body.has_method("add_buff"):
                                                                                var b = on_hit_buff.duplicate(true)
                                                                                if b is DamageOverTimeBuff:
                                                                                                var dot_dict = {b.damage_type: Vector2(b.base_damage_low, b.base_damage_high)}
                                                                                                var dot_map = user.stats.compute_damage(dot_dict, tags)
                                                                                                b.damage_per_second = dot_map[b.damage_type]
                                                                                body.add_buff(b)
                                                                if on_hit_effect:
                                                                                var eff = on_hit_effect.instantiate()
                                                                                body.add_child(eff)
		if explosion_effect:
				var e = explosion_effect.instantiate()
				e.global_transform.origin = origin
				e.scale = Vector3.ONE * explosion_radius * mult
				user.get_parent().add_child(e)
