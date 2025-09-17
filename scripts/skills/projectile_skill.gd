extends Skill
class_name ProjectileSkill

@export var speed: float = 10.0
@export var range: float = 15.0
@export var explosion_radius: float = 0.0
@export var projectile_scene: PackedScene # Scene for projectile; placeholder sphere used if null
@export var on_hit_effect: PackedScene # Effect spawned on bodies struck
@export var explosion_effect: PackedScene # Effect placed at explosion center
@export var on_hit_buff: Buff # Buff or debuff applied to bodies hit

## Launches a projectile toward the cursor.  Damage, on-hit buffs and optional
## explosions are resolved using metadata stored on the spawned projectile so
## the behaviour survives even if the caster is removed mid-flight.
func perform(user) -> void:
	if user == null or not (user is Node3D):
		return
	var actor: Node3D = user
	var direction := Vector3.ZERO
	if user.has_method("_get_click_direction"):
		direction = user._get_click_direction()
	else:
		direction = -actor.global_transform.basis.z
	if direction == Vector3.ZERO:
		return
	actor.look_at(actor.global_transform.origin + direction, Vector3.UP)
	var projectile := _create_projectile()
	if projectile == null:
		return
	var dmg_map: Dictionary = {}
	if "stats" in user and user.stats:
		var base_dict := _build_base_damage_dict(user)
		dmg_map = user.stats.compute_damage(base_dict, get_tags())
	var buff_template := _prepare_buff_instance(on_hit_buff, user)
	var aoe_mult := 1.0
	if "stats" in user and user.stats:
		aoe_mult = user.stats.get_aoe_multiplier()
# Cache all data needed to resolve the hit so we can apply damage even if the
# caster dies while the projectile is active.
projectile.set_meta("dmg_map", dmg_map)
projectile.set_meta("buff_template", buff_template)
projectile.set_meta("aoe_mult", aoe_mult)
projectile.set_meta("is_player", user.is_in_group("player"))
	projectile.body_entered.connect(_on_projectile_body_entered.bind(projectile))
	var parent := actor.get_parent()
	if parent == null:
		return
	parent.add_child(projectile)
	projectile.global_transform.origin = actor.global_transform.origin + direction
	projectile.position.y += 2
	var look_target := projectile.global_transform.origin + direction
	projectile.look_at(look_target, Vector3.UP)
	var travel_time := range / max(speed, 0.001)
	var tween := projectile.create_tween()
	tween.tween_property(projectile, "global_transform:origin", actor.global_transform.origin + direction * range, travel_time)
	tween.finished.connect(Callable(self, "_on_projectile_finished").bind(projectile))

func _create_projectile():
	if projectile_scene:
		return projectile_scene.instantiate()
	var p := Area3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.2
	var collider := CollisionShape3D.new()
	collider.shape = shape
	p.add_child(collider)
	var mesh := MeshInstance3D.new()
	mesh.mesh = SphereMesh.new()
	p.add_child(mesh)
	return p

func _on_projectile_body_entered(body, projectile):
	if not is_instance_valid(projectile):
		return
	var is_player := projectile.has_meta("is_player") and projectile.get_meta("is_player")
	var dmg_map: Dictionary = {}
	if projectile.has_meta("dmg_map"):
		dmg_map = projectile.get_meta("dmg_map")
	var buff_template := null
	if projectile.has_meta("buff_template"):
		buff_template = projectile.get_meta("buff_template")
	_apply_damage_bundle(body, dmg_map, buff_template, is_player, on_hit_effect)
	_explode(projectile)
	projectile.queue_free()

func _on_projectile_finished(projectile):
	_explode(projectile)
	if is_instance_valid(projectile):
		projectile.queue_free()

func _explode(projectile):
if not is_instance_valid(projectile):
return
var origin := projectile.global_transform.origin
if explosion_radius <= 0.0:
		if explosion_effect and projectile.get_parent():
			var eff := explosion_effect.instantiate()
			eff.global_transform.origin = origin
			projectile.get_parent().add_child(eff)
		return
	var mult := 1.0
	if projectile.has_meta("aoe_mult"):
		mult = projectile.get_meta("aoe_mult")
	var shape := SphereShape3D.new()
	shape.radius = explosion_radius * mult
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), origin)
	params.collide_with_bodies = true
	var world := projectile.get_world_3d()
	if world == null:
		return
var results := world.direct_space_state.intersect_shape(params, 1024)
var dmg_map: Dictionary = {}
	if projectile.has_meta("dmg_map"):
		dmg_map = projectile.get_meta("dmg_map")
	var buff_template := null
	if projectile.has_meta("buff_template"):
		buff_template = projectile.get_meta("buff_template")
	var is_player := projectile.has_meta("is_player") and projectile.get_meta("is_player")
	for result in results:
		var body := result.get("collider")
		if body:
			_apply_damage_bundle(body, dmg_map, buff_template, is_player, on_hit_effect)
if explosion_effect and projectile.get_parent():
var e := explosion_effect.instantiate()
e.global_transform.origin = origin
e.scale = Vector3.ONE * explosion_radius * mult
projectile.get_parent().add_child(e)
