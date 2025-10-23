extends Skill
class_name ProjectileSkill

# ======= Core projectile params =======
@export var speed: float = 10.0
@export var range: float = 15.0
@export var explosion_radius: float = 0.0
@export var projectile_scene: PackedScene
@export var on_hit_effect: PackedScene
@export var explosion_effect: PackedScene
@export var on_hit_buff: Buff

# ======= Explode / Fizzle controls =======
@export var explode_on_hit: bool = true          # explode when it hits something
@export var explode_on_finish: bool = true       # explode when tween finishes
@export var on_explode_skill: ProjectileSkill    # optional secondary skill fired from explosion origin
@export var on_fizzle_skill: ProjectileSkill     # optional secondary skill when it times out
@export var fizzle_enabled: bool = false         # if true and !explode_on_finish, use fizzle path
@export var fizzle_effect: PackedScene           # optional VFX for fizzle

# Grace window to ignore the first collision with the body that caused a chain
@export var chain_ignore_first_body_time: float = 0.08  # seconds

# ======= Launcher pattern controls =======
enum FirePattern { SINGLE, ARC, SEQUENTIAL, NOVA }
@export var pattern: FirePattern = FirePattern.SINGLE
@export var projectile_count: int = 1
@export var arc_spread_deg: float = 20.0
@export var shot_delay: float = 0.08
@export var yaw_jitter_deg: float = 2.5
@export var follow_user: bool = true
@export var spawn_offset: float = 1.0
@export var spawn_height: float = 2.0
@export var keep_aim_live: bool = false

# -----------------------
# Utilities
# -----------------------

func _flat_xz(v: Vector3) -> Vector3:
	return v - v.project(Vector3.UP)

# -----------------------
# Entry point
# -----------------------

func perform(user):
	if user == null:
		return

	# 1) Acquire base aim (flattened)
	var raw_dir: Vector3
	if user.has_method("_get_click_direction"):
		raw_dir = user._get_click_direction()
	else:
		raw_dir = -user.global_transform.basis.z

	var dir := _flat_xz(raw_dir)
	if dir.length_squared() < 1e-6:
		dir = _flat_xz(-user.global_transform.basis.z)
	if dir.length_squared() < 1e-6:
		return
	dir = dir.normalized()

	# 2) Face only around Y
	var user_pos: Vector3 = user.global_position
	var look_target := Vector3(user_pos.x - dir.x, user_pos.y, user_pos.z - dir.z)
	user.look_at(look_target, Vector3.UP)

	# 3) Snapshot combat state once
	var base_dict = _build_base_damage_dict(user)
	var dmg_map = user.stats.compute_damage(base_dict, tags)

	var buff_snapshot
	if on_hit_buff:
		buff_snapshot = on_hit_buff.duplicate(true)
		if buff_snapshot is DamageOverTimeBuff:
			var dot_dict = {buff_snapshot.damage_type: Vector2(buff_snapshot.base_damage_low, buff_snapshot.base_damage_high)}
			var dot_map = user.stats.compute_damage(dot_dict, tags)
			buff_snapshot.damage_per_second = dot_map[buff_snapshot.damage_type]

	# 4) Launch from the user
	_perform_from(user, dir, user.global_transform, dmg_map, buff_snapshot, follow_user)

# -----------------------
# Fire from arbitrary origin/orientation (used by explode/fizzle)
# -----------------------

func _perform_from(user: Node3D, dir: Vector3, basis_from: Transform3D, dmg_map: Dictionary, buff_snapshot, follow_user_override: bool) -> void:
	var launcher := ProjectileLauncher.new()
	launcher.skill = self
	launcher.user = user
	launcher.base_dir = dir
	launcher.speed = speed
	launcher.range = range
	launcher.projectile_scene = projectile_scene
	launcher.on_hit_effect = on_hit_effect
	launcher.explosion_effect = explosion_effect
	launcher.explosion_radius = explosion_radius

	launcher.follow_user = follow_user_override
	launcher.spawn_offset = spawn_offset
	launcher.spawn_height = spawn_height
	launcher.keep_aim_live = keep_aim_live

	launcher.pattern = pattern
	launcher.projectile_count = max(1, projectile_count)
	launcher.arc_spread_deg = arc_spread_deg
	launcher.shot_delay = max(0.0, shot_delay)
	launcher.yaw_jitter_deg = yaw_jitter_deg

	# snapshots
	launcher.dmg_map = dmg_map
	launcher.buff_snapshot = buff_snapshot
	launcher.aoe_mult = user.stats.get_aoe_multiplier()
	launcher.is_player = user.is_in_group("player")

	# parent + start
	user.add_child(launcher, true)
	launcher.global_transform = basis_from
	launcher.begin()

# -----------------------
# Projectile factory
# -----------------------

func _create_projectile():
	if projectile_scene:
		return projectile_scene.instantiate()

	# Fallback: tiny sphere Area3D
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

# -----------------------
# Callbacks from launcher/projectiles
# -----------------------

func _on_projectile_body_entered(body, projectile):
	# Ignore the first collision with the body that caused us, within a small grace window.
	var ignore_body = projectile.get_meta("ignore_body")
	if ignore_body != null and body == ignore_body:
		var t0 = int(projectile.get_meta("spawn_time_ms"))
		var grace = int(projectile.get_meta("ignore_time_ms"))
		if grace > 0:
			var now = Time.get_ticks_msec()
			if now - t0 <= grace:
				return  # skip this initial overlap

	var is_player = projectile.get_meta("is_player")
	var hit_pos: Vector3 = projectile.global_transform.origin

	# Try to center the hit position on the body (visually nicer)
	if body:
		var p = body.global_transform.origin
		p.y = mid_y_of_body(body)
		hit_pos = p

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
				body.get_tree().current_scene.add_child(eff)
				eff.global_transform.origin = hit_pos

	# Ignore self-hit cases
	if is_player and body and body.is_in_group("player"):
		return

	# Explode/chain at the actual hit position
	if explode_on_hit:
		_explode(projectile, true, hit_pos, body)
	else:
		_chain_from_explode(projectile, true, hit_pos, body)

	projectile.queue_free()

func _on_projectile_finished(projectile):
	# End position if it didn't collide
	var end_pos: Vector3 = projectile.global_transform.origin
	if fizzle_enabled and not explode_on_finish:
		_fizzle(projectile)  # uses end_pos internally
	else:
		if explode_on_finish:
			_explode(projectile, false, end_pos, null)
		else:
			_chain_from_explode(projectile, false, end_pos, null)
	projectile.queue_free()

# -----------------------
# Explode / Fizzle / Chain
# -----------------------

func _explode(projectile, was_hit: bool, origin: Vector3, hit_body: Node3D = null):
	if explosion_radius <= 0.0:
		if explosion_effect:
			var eff = explosion_effect.instantiate()
			eff.global_transform.origin = origin
			projectile.get_parent().add_child(eff)
		_chain_from_explode(projectile, was_hit, origin, hit_body)
		return

	var mult = projectile.get_meta("aoe_mult")

	# Physics query
	var shape = SphereShape3D.new()
	shape.radius = explosion_radius * mult
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), origin)
	params.collide_with_bodies = true

	var space = projectile.get_world_3d().direct_space_state
	var bodies = space.intersect_shape(params, 1024)

	var dmg_map = projectile.get_meta("dmg_map")
	var buff_snapshot = projectile.get_meta("buff_snapshot")
	var is_player = projectile.get_meta("is_player")

	for result in bodies:
		var b = result.get("collider")
		if b and b.has_method("take_damage"):
			if (is_player and b.is_in_group("enemy")) or (not is_player and b.is_in_group("player")):
				for dt in dmg_map.keys():
					var dmg = dmg_map[dt]
					if dmg > 0:
						b.take_damage(dmg, dt)
				if buff_snapshot and b.has_method("add_buff"):
					b.add_buff(buff_snapshot.duplicate(true))
				if on_hit_effect:
					var eff = on_hit_effect.instantiate()
					var p = b.global_transform.origin
					p.y = mid_y_of_body(b)
					b.get_tree().current_scene.add_child(eff)
					eff.global_transform.origin = p

	if explosion_effect:
		var e = explosion_effect.instantiate()
		projectile.get_parent().add_child(e)
		e.global_transform.origin = origin
		e.scale = Vector3.ONE * explosion_radius * mult

	_chain_from_explode(projectile, was_hit, origin, hit_body)

func _fizzle(projectile):
	var origin: Vector3 = projectile.global_transform.origin
	if fizzle_effect:
		var f = fizzle_effect.instantiate()
		projectile.get_parent().add_child(f)
		f.global_transform.origin = origin

	if on_fizzle_skill:
		_fire_secondary_skill_from(projectile, on_fizzle_skill, origin, null)

func _chain_from_explode(projectile, was_hit: bool, origin: Vector3, hit_body: Node3D = null) -> void:
	if on_explode_skill:
		_fire_secondary_skill_from(projectile, on_explode_skill, origin, hit_body)

func _fire_secondary_skill_from(projectile, secondary_skill: ProjectileSkill, origin: Vector3, hit_body: Node3D = null) -> void:
	if secondary_skill == null:
		return

	var caster: Node3D = projectile.get_meta("caster")
	if caster == null or not is_instance_valid(caster):
		return

	# Direction for chained skill = projectile's travel direction (flattened),
	# fallback to caster forward if missing.
	var dir: Vector3 = projectile.get_meta("dir")
	if dir == Vector3.ZERO:
		dir = -caster.global_transform.basis.z
	dir = _flat_xz(dir)
	if dir.length_squared() > 1e-6:
		dir = dir.normalized()
	else:
		dir = Vector3.FORWARD

	# Build snapshots using the SECONDARY skill's own tags/buff
	var base_dict = secondary_skill._build_base_damage_dict(caster)
	var dmg_map = caster.stats.compute_damage(base_dict, secondary_skill.tags)

	var buff_snapshot
	if secondary_skill.on_hit_buff:
		buff_snapshot = secondary_skill.on_hit_buff.duplicate(true)
		if buff_snapshot is DamageOverTimeBuff:
			var dot_dict = {buff_snapshot.damage_type: Vector2(buff_snapshot.base_damage_low, buff_snapshot.base_damage_high)}
			var dot_map = caster.stats.compute_damage(dot_dict, secondary_skill.tags)
			buff_snapshot.damage_per_second = dot_map[buff_snapshot.damage_type]

	# Create a launcher manually so we can inject ignore-body/time and zero offsets
	var origin_xform := Transform3D(Basis(), origin)

	var launcher := ProjectileLauncher.new()
	launcher.skill = secondary_skill
	launcher.user = caster
	launcher.base_dir = dir
	launcher.speed = secondary_skill.speed
	launcher.range = secondary_skill.range
	launcher.projectile_scene = secondary_skill.projectile_scene
	launcher.on_hit_effect = secondary_skill.on_hit_effect
	launcher.explosion_effect = secondary_skill.explosion_effect
	launcher.explosion_radius = secondary_skill.explosion_radius

	launcher.follow_user = false
	launcher.spawn_offset = 0.0
	launcher.spawn_height = 0.0
	launcher.keep_aim_live = false

	launcher.pattern = secondary_skill.pattern
	launcher.projectile_count = max(1, secondary_skill.projectile_count)
	launcher.arc_spread_deg = secondary_skill.arc_spread_deg
	launcher.shot_delay = max(0.0, secondary_skill.shot_delay)
	launcher.yaw_jitter_deg = secondary_skill.yaw_jitter_deg

	# snapshots
	launcher.dmg_map = dmg_map
	launcher.buff_snapshot = buff_snapshot
	launcher.aoe_mult = caster.stats.get_aoe_multiplier()
	launcher.is_player = caster.is_in_group("player")

	# Pass the initial ignore (the body we hit) and grace time
	launcher.initial_ignore_body = hit_body
	launcher.initial_ignore_time = chain_ignore_first_body_time

	# Place the launcher at the explosion/fizzle origin in world space
	var parent_for_launcher: Node = caster.get_parent()
	parent_for_launcher.add_child(launcher, true)
	launcher.global_transform = origin_xform
	launcher.begin()

# -----------------------
# Bounds helpers
# -----------------------

func _world_y_bounds(root: Node3D) -> Vector2:
	var min_y := INF
	var max_y := -INF
	var stack: Array[Node3D] = [root]

	while stack.size() > 0:
		var n: Node3D = stack.pop_back()

		# Meshes (most accurate visually)
		if n is MeshInstance3D and n.mesh:
			var aabb: AABB = n.mesh.get_aabb()
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
				if wc.y < min_y:
					min_y = wc.y
				if wc.y > max_y:
					max_y = wc.y

		# Collision shapes (approximate fallback)
		elif n is CollisionShape3D and n.shape:
			var gt := n.global_transform
			var sc := gt.basis.get_scale().abs()
			var oy := gt.origin.y

			if n.shape is BoxShape3D:
				var half = (n.shape.size * sc) * 0.5
				if oy - half.y < min_y:
					min_y = oy - half.y
				if oy + half.y > max_y:
					max_y = oy + half.y
			elif n.shape is SphereShape3D:
				var r = n.shape.radius * max(sc.x, max(sc.y, sc.z))
				if oy - r < min_y:
					min_y = oy - r
				if oy + r > max_y:
					max_y = oy + r
			elif n.shape is CapsuleShape3D:
				var r2 = n.shape.radius * max(sc.x, sc.z)
				var h_cyl = n.shape.height * sc.y
				var h_total = h_cyl + 2.0 * r2
				if oy - h_total * 0.5 < min_y:
					min_y = oy - h_total * 0.5
				if oy + h_total * 0.5 > max_y:
					max_y = oy + h_total * 0.5
			elif n.shape is CylinderShape3D:
				var r3 = n.shape.radius * max(sc.x, sc.z)
				var h = n.shape.height * sc.y
				if oy - h * 0.5 < min_y:
					min_y = oy - h * 0.5
				if oy + h * 0.5 > max_y:
					max_y = oy + h * 0.5

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
