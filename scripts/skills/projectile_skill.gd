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
	var look_target = projectile.global_transform.origin + direction
	projectile.look_at(look_target, Vector3.UP)
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
	var is_player = projectile.get_meta("is_player")
	if body and body.has_method("take_damage"):
			
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
						var p = body.global_transform.origin
						p.y = mid_y_of_body(body)
						eff.global_transform.origin = p
						body.get_tree().current_scene.add_child(eff)
	if(is_player and body.is_in_group("player")):
		return
	_explode(projectile)
	projectile.queue_free()

func _on_projectile_finished(projectile):
	_explode(projectile)
	projectile.queue_free()

func _explode(projectile):
	print("BOOM!")
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
									var p = body.global_transform.origin
									p.y = mid_y_of_body(body)
									eff.global_transform.origin = p
									body.get_tree().current_scene.add_child(eff)
	if explosion_effect:
			var e = explosion_effect.instantiate()
			e.global_transform.origin = origin
			e.scale = Vector3.ONE * explosion_radius * mult
			projectile.get_parent().add_child(e)
			
# --- Bounds helpers (Godot 4) ---

func _world_y_bounds(root: Node3D) -> Vector2:
	var min_y := INF
	var max_y := -INF
	var stack: Array[Node3D] = [root]

	while stack.size() > 0:
		var n: Node3D = stack.pop_back()

		# Meshes (most accurate visually)
		if n is MeshInstance3D and n.mesh:
			var aabb: AABB = n.mesh.get_aabb() # local space
			# Transform AABB corners to world space and track y-extents
			var xform := n.global_transform
			var p := aabb.position
			var s := aabb.size
			var corners := [
				p,
				p + Vector3(s.x, 0, 0),
				p + Vector3(0, s.y, 0),
				p + Vector3(0, 0, s.z),
				p + Vector3(s.x, s.y, 0),
				p + Vector3(s.x, 0, s.z),
				p + Vector3(0, s.y, s.z),
				p + s
			]
			for c in corners:
				var wc = xform * c
				min_y = min(min_y, wc.y)
				max_y = max(max_y, wc.y)

		# Collision shapes (approximate fallback)
		elif n is CollisionShape3D and n.shape:
			var gt := n.global_transform
			var sc := gt.basis.get_scale().abs()
			var oy := gt.origin.y

			match n.shape:
				BoxShape3D:
					var half = (n.shape.size * sc) * 0.5
					min_y = min(min_y, oy - half.y)
					max_y = max(max_y, oy + half.y)

				SphereShape3D:
					var r = n.shape.radius * max(sc.x, max(sc.y, sc.z))
					min_y = min(min_y, oy - r)
					max_y = max(max_y, oy + r)

				CapsuleShape3D:
					# Capsule aligned to Y in Godot
					var r = n.shape.radius * max(sc.x, sc.z)
					var h_cyl = n.shape.height * sc.y
					var h_total = h_cyl + 2.0 * r
					min_y = min(min_y, oy - h_total * 0.5)
					max_y = max(max_y, oy + h_total * 0.5)

				CylinderShape3D:
					var r = n.shape.radius * max(sc.x, sc.z)
					var h = n.shape.height * sc.y
					min_y = min(min_y, oy - h * 0.5)
					max_y = max(max_y, oy + h * 0.5)

		# Traverse
		for c in n.get_children():
			if c is Node3D:
				stack.push_back(c)

	# If nothing was found, default to root's Y
	if min_y == INF:
		var y := root.global_transform.origin.y
		return Vector2(y, y)
	return Vector2(min_y, max_y)

func mid_y_of_body(root: Node3D) -> float:
	var b := _world_y_bounds(root)
	return 0.5 * (b.x + b.y)
