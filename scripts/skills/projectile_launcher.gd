extends Node3D
class_name ProjectileLauncher

# Wired in by the skill:
var skill: ProjectileSkill
var user: Node3D
var base_dir: Vector3 = Vector3.FORWARD
var speed: float
var range: float
var projectile_scene: PackedScene
var on_hit_effect: PackedScene
var explosion_effect: PackedScene
var explosion_radius: float = 0.0
var follow_user: bool = true
var spawn_offset: float = 1.0
var spawn_height: float = 2.0
var keep_aim_live: bool = false

# Snapshotted combat data
var dmg_map: Dictionary
var buff_snapshot
var aoe_mult: float = 1.0
var is_player: bool = true

# Pattern config:
var pattern: int = ProjectileSkill.FirePattern.SINGLE
var projectile_count: int = 1
var arc_spread_deg: float = 20.0
var shot_delay: float = 0.08
var yaw_jitter_deg: float = 2.5

# Ignore-first-collision seed (for chains)
var initial_ignore_body: Node3D = null
var initial_ignore_time: float = 0.08  # seconds

func _process(_dt):
	if follow_user and is_instance_valid(user):
		# Stay mounted to user only if following is enabled
		global_transform = user.global_transform

func begin() -> void:
	# Ensure parenting matches follow_user
	if is_instance_valid(user):
		var target_parent: Node = user if follow_user else user.get_parent()
		if get_parent() != target_parent:
			var gt := global_transform
			target_parent.add_child(self)
			global_transform = gt
	_run()

func _flat_xz(v: Vector3) -> Vector3:
	return v - v.project(Vector3.UP)

func _yaw(vec: Vector3, deg: float) -> Vector3:
	var rad = deg_to_rad(deg)
	return (Basis(Vector3.UP, rad) * vec).normalized()

func _aim_dir() -> Vector3:
	if not is_instance_valid(user):
		return base_dir
	if keep_aim_live and user.has_method("_get_click_direction"):
		var raw = user._get_click_direction()
		var f = _flat_xz(raw)
		if f.length_squared() > 1e-6:
			return f.normalized()
		return base_dir
	return base_dir

func _run() -> void:
	if pattern == ProjectileSkill.FirePattern.SINGLE:
		var d = _yaw(_aim_dir(), randf_range(-yaw_jitter_deg, yaw_jitter_deg))
		_spawn_shot(d)
	elif pattern == ProjectileSkill.FirePattern.ARC:
		var count = max(1, projectile_count)
		if count == 1:
			var d1 = _yaw(_aim_dir(), randf_range(-yaw_jitter_deg, yaw_jitter_deg))
			_spawn_shot(d1)
		else:
			var half = arc_spread_deg * 0.5
			for i in range(count):
				var t = 0.0
				if count > 1:
					t = float(i) / float(count - 1)  # 0..1
				var rel = lerp(-half, half, t)
				var jitter = randf_range(-yaw_jitter_deg, yaw_jitter_deg)
				var d = _yaw(_aim_dir(), rel + jitter)
				_spawn_shot(d)
	elif pattern == ProjectileSkill.FirePattern.SEQUENTIAL:
		for i in range(projectile_count):
			var jitter = randf_range(-yaw_jitter_deg, yaw_jitter_deg)
			var d = _yaw(_aim_dir(), jitter)
			_spawn_shot(d)
			if i < projectile_count - 1 and shot_delay > 0.0:
				await get_tree().create_timer(shot_delay).timeout
	elif pattern == ProjectileSkill.FirePattern.NOVA:
		var count = max(1, projectile_count)
		var step = 360.0 / float(count)
		var aim = _aim_dir()
		for i in range(count):
			var angle = i * step + randf_range(-yaw_jitter_deg, yaw_jitter_deg)
			var d = _yaw(aim, angle)
			_spawn_shot(d)
	else:
		_spawn_shot(_aim_dir())

	# One frame so tweens/signals hook, then self-destruct
	await get_tree().process_frame
	queue_free()

func _spawn_shot(dir: Vector3) -> void:
	if not is_instance_valid(skill) or not is_instance_valid(user):
		return

	var projectile = skill._create_projectile()

	# Pack metas for downstream logic
	projectile.set_meta("dmg_map", dmg_map)
	projectile.set_meta("buff_snapshot", buff_snapshot)
	projectile.set_meta("aoe_mult", aoe_mult)
	projectile.set_meta("is_player", is_player)
	projectile.set_meta("caster", user)
	projectile.set_meta("dir", dir)

	# Grace window to ignore the body we just hit (for chained shots)
	projectile.set_meta("ignore_body", initial_ignore_body)
	projectile.set_meta("spawn_time_ms", Time.get_ticks_msec())
	projectile.set_meta("ignore_time_ms", int(initial_ignore_time * 1000.0))

	# Connect collision to the skill’s handlers
	if projectile.has_signal("body_entered"):
		projectile.body_entered.connect(skill._on_projectile_body_entered.bind(projectile))

	# Parent projectiles to world (user's parent), not under the launcher
	var parent_for_projectiles: Node = user.get_parent()
	parent_for_projectiles.add_child(projectile)

	# Spawn from the LAUNCHER position (not the user)
	var origin := global_position + dir * spawn_offset
	origin.y += spawn_height
	projectile.global_position = origin

	# Face horizontally along the shot direction
	var ppos = projectile.global_position
	projectile.look_at(Vector3(ppos.x + dir.x, ppos.y, ppos.z + dir.z), Vector3.UP)

	# Travel tween (pure XZ)
	var travel_time = skill.range / max(0.001, speed)
	var target = ppos + dir * skill.range
	var tween = projectile.create_tween()
	tween.tween_property(projectile, "global_position", target, travel_time)
	tween.connect("finished", Callable(skill, "_on_projectile_finished").bind(projectile))
