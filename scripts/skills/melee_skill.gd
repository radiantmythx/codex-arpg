extends Skill
class_name MeleeSkill

@export var range: float = 2.0 ## Radius of the swing in metres.
@export var angle: float = 45.0
@export var on_hit_effect: PackedScene ## Effect spawned on struck bodies.
@export var on_hit_buff: Buff ## Buff or debuff applied to bodies hit.

## Performs a simple radial sweep in front of the user and applies damage to
## valid targets. The implementation relies on the shared helpers in `Skill`
## so it integrates with the animation-driven combat flow in `Player.gd`.
func perform(user) -> void:
if user == null or not (user is Node3D):
return
var actor: Node3D = user
var direction := Vector3.ZERO
if user.has_method("_get_click_direction"):
direction = user._get_click_direction()
else:
direction = -actor.global_transform.basis.z
actor.look_at(actor.global_transform.origin + direction, Vector3.UP)
if direction == Vector3.ZERO:
return
var parent := actor.get_parent()
if parent == null:
return
var attack_area := Area3D.new()
var shape := CylinderShape3D.new()
shape.height = 1.0
shape.radius = range
var collider := CollisionShape3D.new()
collider.shape = shape
attack_area.add_child(collider)
attack_area.transform.origin = actor.global_transform.origin + direction * range
parent.add_child(attack_area)
var timer := Timer.new()
timer.wait_time = 0.1
timer.one_shot = true
timer.autostart = true
timer.timeout.connect(Callable(attack_area, "queue_free"))
attack_area.add_child(timer)
var params := PhysicsShapeQueryParameters3D.new()
params.shape = shape
params.transform = attack_area.global_transform
params.collide_with_bodies = true
var space := actor.get_world_3d()
if space == null:
return
var results := space.direct_space_state.intersect_shape(params, 32)
var dmg_map: Dictionary = {}
if "stats" in user and user.stats:
var base_dict := _build_base_damage_dict(user)
dmg_map = user.stats.compute_damage(base_dict, get_tags())
var buff_template := _prepare_buff_instance(on_hit_buff, user)
var is_player := user.is_in_group("player")
for result in results:
var body := result.get("collider")
if body:
_apply_damage_bundle(body, dmg_map, buff_template, is_player, on_hit_effect)
