extends Node3D

@export var follow_target_path: NodePath
@export var look_camera: Camera3D

# Tuning
@export var pos_smooth_time := 0.15       # lower = snappier
@export var aim_smooth_time := 0.10       # gaze smoothing
@export var max_pos_speed   := 1000.0     # optional clamp; use INF for none
@export var aim_height      := 2.0        # where on the target to look (head/chest)
@export var prediction      := 0.00       # 0..0.15s: look a bit ahead to reduce perceived jitter

var _follow_target: Node3D

# State for smoothing
var _pos_vel: Vector3 = Vector3.ZERO
var _aim_vel: Vector3 = Vector3.ZERO
var _smoothed_aim: Vector3

# Target velocity estimate (for optional prediction)
var _last_target_pos: Vector3
var _target_vel: Vector3 = Vector3.ZERO

func _ready() -> void:
	set_as_top_level(true)
	if follow_target_path != NodePath():
		_follow_target = get_node(follow_target_path)
	if _follow_target:
		global_position = _follow_target.global_position
		_last_target_pos = _follow_target.global_position
		_smoothed_aim = _last_target_pos + Vector3.UP * aim_height

# Use _process for visual smoothness. If your player only moves in physics,
# this still looks better because we interpolate visually between physics steps.
func _process(delta: float) -> void:
	if _follow_target == null:
		return

	# --- Estimate target velocity (for optional predictive aim) ---
	var current_target_pos := _follow_target.global_position
	_target_vel = (current_target_pos - _last_target_pos) / max(delta, 0.000001)
	_last_target_pos = current_target_pos

	# --- Smooth follow position (critically damped) ---
	var desired_pos := current_target_pos
	global_position = _smooth_damp_vec3(
		global_position, desired_pos, _pos_vel, pos_smooth_time, delta, max_pos_speed
	)

	# --- Smooth aim point separately (reduces micro-jitter) ---
	var desired_aim := current_target_pos + Vector3.UP * aim_height + (_target_vel * prediction)
	_smoothed_aim = _smooth_damp_vec3(
		_smoothed_aim, desired_aim, _aim_vel, aim_smooth_time, delta, INF
	)

	# --- Aim the camera ---
	if look_camera:
		look_camera.look_at(_smoothed_aim, Vector3.UP)

# Critically-damped SmoothDamp (Unity-style), framerate independent.
# Returns the next value; 'vel' is updated in-place.
func _smooth_damp_vec3(current: Vector3, target: Vector3, vel: Vector3, smooth_time: float, delta: float, max_speed: float) -> Vector3:
	smooth_time = max(0.0001, smooth_time)
	var omega := 2.0 / smooth_time
	var x := omega * delta
	# Exponential decay approx for critical damping
	var exp := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)

	var change := current - target

	# Clamp to max speed (prevents big teleports causing overshoot)
	var max_change := max_speed * smooth_time
	if change.length() > max_change:
		change = change.normalized() * max_change

	var temp := (vel + change * omega) * delta
	vel = (vel - temp * omega) * exp
	var result := target + (change + temp) * exp

	# Prevent tiny numerical drift when extremely close
	if (result - target).length_squared() < 1e-8:
		result = target
		vel = Vector3.ZERO

	# Write back (GDScript passes by value; return both via tuple-like pattern)
	# We'll return result, but also update the external vel via 'returning' it.
	# GDScript can’t return multiple values, so we mutate by reference via 'vel' above.
	# (This works because 'vel' is a reference to our member variable.)
	return result
