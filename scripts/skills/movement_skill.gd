class_name MovementSkill
extends Skill

## MovementSkill moves the user quickly toward the clicked location.
## While active the player travels at a multiple of their move speed and
## may optionally deal damage in a radius, spawn various particle effects
## and phase through other bodies.

# Whether collision layers should be disabled so the user can pass through
# other objects while moving.  Border walls are expected to remain solid
# because they use different collision layers.
@export var phase_through: bool = false

# If true the movement ends early when the body collides with something.
@export var stop_on_collision: bool = true

@export var max_distance:float = 20.0

# Radius of damage applied around the user while moving.  Zero disables
# damage and the expensive overlap queries.
@export var damage_radius: float = 0.0

# Optional effects used at different points during the movement.
@export var on_cast_effect: PackedScene
@export var on_arrival_effect: PackedScene
@export var active_effect: PackedScene


func perform(user):
	if user == null:
		return
	var target: Vector3
	if user.has_method("_get_click_position"):
		target = user._get_click_position()
	else:
		return
	var origin: Vector3 = user.global_position
	var direction: Vector3 = target - origin
	var distance: float = direction.length()
	if distance <= 0.01:
		return
	direction = direction.normalized()
	print("Target: ", target, " Origin: ", origin, " Direction: ", direction)
	var dmg_map: Dictionary = {}
	if damage_radius > 0.0 and user.stats:
		var base_dict = _build_base_damage_dict(user)
		dmg_map = user.stats.compute_damage(base_dict, tags)
	# Delegate the actual motion to the user so it can integrate with
	# existing movement code.

	
	
	if user.has_method("start_movement_skill"):
		user.start_movement_skill(self, direction, distance, dmg_map)
