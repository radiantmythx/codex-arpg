class_name Skill
extends Resource

## Base resource for all active skills.
##
## Each subclass implements `perform(user)` which executes the skill logic
## when the owning actor (player, enemy, etc.) triggers it.  The base class
## provides helpers for common bookkeeping such as tag normalisation, damage
## dictionary construction and creating buff instances.  The goal is to keep
## individual skill scripts focused on their unique behaviour while the
## reusable glue lives here.

@export var name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var mana_cost: float = 0.0
@export var cooldown: float = 0.0
@export var duration: float = 0.0
@export var move_multiplier: float = 1.0
@export var damage_type: Stats.DamageType = Stats.DamageType.PHYSICAL
@export var base_damage_low: float = 0.0
@export var base_damage_high: float = 0.0
@export var tags: Array[String] = []
@export var animation_name: StringName = &""
@export var attack_time: float = 0.0 ## Seconds into the animation when the attack is applied.
@export var cancel_time: float = 0.0 ## Seconds into the animation when the remainder can be cancelled.

func perform(user: Node) -> void:
"""Execute the skill for the given user.  Subclasses override this."""
pass

## Returns a lowercase copy of the configured tags.
##
## `Player.gd` and other gameplay systems expect tags to be lowercase when
## checking for keywords such as `melee` or `spell`.  Many existing resources
## store them with capitalisation ("Spell", "AoE"), so normalising them here
## keeps older data working with the new casting flow.
func get_tags() -> Array[String]:
var result: Array[String] = []
for tag in tags:
if typeof(tag) == TYPE_STRING:
var cleaned := String(tag).strip_edges().to_lower()
if not cleaned.is_empty():
result.append(cleaned)
return result

## Helper to construct the damage dictionary passed to `Stats.compute_damage`.
##
## By default this uses the skill's own base damage values but, if the user
## (player or enemy) exposes a `get_base_damage_dict(tags)` method, those values
## are merged in.  This lets enemies define innate damage ranges and allows
## players to contribute weapon damage only when the skill's tags match the
## weapon type.
func _build_base_damage_dict(user) -> Dictionary:
var dict: Dictionary = {}
var normalized_tags := get_tags()
if user and user.has_method("get_base_damage_dict"):
dict = user.get_base_damage_dict(normalized_tags)
dict[damage_type] = Vector2(base_damage_low, base_damage_high)
return dict

## Creates a buff instance tailored for the current cast.
##
## * If `duplicate` is `true` (the default), a deep copy of the supplied buff
##   is created.  This prevents shared resources from having their internal
##   state mutated by multiple entities.
## * When the buff is a `DamageOverTimeBuff` the helper computes its final
##   damage-per-second using the user's offensive stats so the effect scales
##   with the caster just like direct damage.
## * A non-duplicated DoT will still be copied to avoid modifying the shared
##   resource in-place.
func _prepare_buff_instance(buff: Buff, user, duplicate: bool = true) -> Buff:
if buff == null:
return null
var instance: Buff = buff
if duplicate or instance is DamageOverTimeBuff:
instance = buff.duplicate(true)
if instance is DamageOverTimeBuff and user and "stats" in user and user.stats:
var dot: DamageOverTimeBuff = instance
var dot_dict := {dot.damage_type: Vector2(dot.base_damage_low, dot.base_damage_high)}
var tags_for_dot := get_tags()
var damage_map := user.stats.compute_damage(dot_dict, tags_for_dot)
dot.damage_per_second = damage_map.get(dot.damage_type, 0.0)
return instance

## Returns true if `body` should take damage from the current caster.
func _is_valid_target(body: Node, is_player: bool) -> bool:
if body == null or not body.has_method("take_damage"):
return false
if is_player:
return body.is_in_group("enemy")
return body.is_in_group("player")

## Applies damage, buffs and optional hit effects to a target body.
func _apply_damage_bundle(body: Node, dmg_map: Dictionary, buff_template: Buff, is_player: bool, effect: PackedScene = null) -> void:
if not _is_valid_target(body, is_player):
return
for dt in dmg_map.keys():
var dmg = dmg_map[dt]
if dmg > 0.0:
body.take_damage(dmg, dt)
if buff_template and body.has_method("add_buff"):
body.add_buff(buff_template.duplicate(true))
if effect and body is Node3D and body.get_tree():
var eff = effect.instantiate()
var origin := (body as Node3D).global_transform.origin
origin.y = get_body_mid_y(body)
eff.global_transform.origin = origin
body.get_tree().current_scene.add_child(eff)

## Calculates the mid-point on the Y axis for a 3D body.
##
## Effects spawned on enemies should appear roughly centred vertically.  We
## inspect meshes first for accuracy and fall back to collision shapes when a
## render mesh is not present.  If nothing is available the body's origin is
## used.
func get_body_mid_y(root: Node3D) -> float:
var bounds := _world_y_bounds(root)
return 0.5 * (bounds.x + bounds.y)

## Shared logic for `get_body_mid_y` – traverses the node hierarchy to find
## vertical bounds in world space.
func _world_y_bounds(root: Node3D) -> Vector2:
var min_y := INF
var max_y := -INF
var stack: Array[Node3D] = [root]
while stack.size() > 0:
var n: Node3D = stack.pop_back()
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
var wc := xform * c
min_y = min(min_y, wc.y)
max_y = max(max_y, wc.y)
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
var r_caps = n.shape.radius * max(sc.x, sc.z)
var h_cyl = n.shape.height * sc.y
var h_total = h_cyl + 2.0 * r_caps
min_y = min(min_y, oy - h_total * 0.5)
max_y = max(max_y, oy + h_total * 0.5)
CylinderShape3D:
var r_cyl = n.shape.radius * max(sc.x, sc.z)
var h = n.shape.height * sc.y
min_y = min(min_y, oy - h * 0.5)
max_y = max(max_y, oy + h * 0.5)
for child in n.get_children():
if child is Node3D:
stack.append(child)
if min_y == INF:
var y := root.global_transform.origin.y
return Vector2(y, y)
return Vector2(min_y, max_y)

## Casts a ray from the camera (or cursor helper) to find a ground point in
## front of the user.  The returned position lives on the horizontal plane at
## the actor's height, matching the behaviour of `_get_click_position` in
## `Player.gd`.
func _get_ground_target_position(user) -> Vector3:
if user == null:
return Vector3.ZERO
if user.has_method("_get_click_position"):
return user._get_click_position()
var actor := user as Node3D
if actor == null:
return Vector3.ZERO
var viewport := actor.get_viewport()
if viewport:
var cam := viewport.get_camera_3d()
if cam:
var mouse := viewport.get_mouse_position()
var ray_origin := cam.project_ray_origin(mouse)
var ray_dir := cam.project_ray_normal(mouse)
if abs(ray_dir.y) > 0.0001:
var plane_y := actor.global_transform.origin.y
var distance := (plane_y - ray_origin.y) / ray_dir.y
if distance >= 0.0:
return ray_origin + ray_dir * distance
return actor.global_transform.origin
