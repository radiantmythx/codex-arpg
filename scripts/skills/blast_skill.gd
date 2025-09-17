extends Skill
class_name BlastSkill

@export var radius: float = 3.0 ## Base explosion radius in metres.
@export var on_hit_effect: PackedScene ## Effect spawned on struck bodies.
@export var explosion_effect: PackedScene ## Effect placed at blast centre.
@export var on_hit_buff: Buff ## Buff or debuff applied to bodies hit.

## Detonates an area at the cursor position, damaging everything inside the
## radius. Works for both the player and AI controlled casters.
func perform(user) -> void:
	if user == null or not (user is Node3D):
		return
	var actor: Node3D = user
	var target := _get_ground_target_position(user)
	var dmg_map: Dictionary = {}
	if "stats" in user and user.stats:
		var base_dict := _build_base_damage_dict(user)
		dmg_map = user.stats.compute_damage(base_dict, get_tags())
	var buff_template := _prepare_buff_instance(on_hit_buff, user)
	var is_player := user.is_in_group("player")
	var mult := 1.0
	if "stats" in user and user.stats:
		mult = user.stats.get_aoe_multiplier()
	_explode(actor, target, dmg_map, buff_template, mult, is_player)

func _explode(actor: Node3D, origin: Vector3, dmg_map: Dictionary, buff_template: Buff, mult: float, is_player: bool) -> void:
	var world := actor.get_world_3d()
	if world == null:
		return
	var shape := SphereShape3D.new()
	shape.radius = max(radius * mult, 0.0)
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), origin)
	params.collide_with_bodies = true
	var results := world.direct_space_state.intersect_shape(params, 1024)
	for result in results:
		var body := result.get("collider")
		if body:
			_apply_damage_bundle(body, dmg_map, buff_template, is_player, on_hit_effect)
	if explosion_effect and actor.get_parent():
		var e := explosion_effect.instantiate()
		e.global_transform.origin = origin
		e.scale = Vector3.ONE * max(radius * mult, 0.01)
		actor.get_parent().add_child(e)
