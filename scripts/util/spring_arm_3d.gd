extends SpringArm3D
class_name PlayerSpringArmCamera

var IS_LOCKED:bool
func set_is_locked(setting:bool):
	IS_LOCKED = setting


@export var horizontal_sensitivity: float = 0.15
@export var vertical_sensitivity: float = 0.15
@export var invert_y: bool = false

@export_range(-89.0, 89.0, 0.1) var min_pitch_deg: float = -45.0
@export_range(-89.0, 89.0, 0.1) var max_pitch_deg: float =  25.0

@export var zoom_speed: float = 2.0
@export var min_zoom: float = 2.0
@export var max_zoom: float = 12.0

@export var gamepad_look_speed: float = 120.0 # deg/sec when using right stick
@export var smooth_reset_time: float = 0.25   # seconds to slerp on reset

var _yaw_deg: float = 0.0    # around Y
var _pitch_deg: float = 10.0 # up/down (clamped)
var _orbiting: bool = false
var _resetting: bool = false
var _reset_time: float = 0.0
var _reset_from_basis: Basis
var _reset_to_basis: Basis

func _ready() -> void:
	# Initialize from current transform so there’s no snap on first frame.
	var euler = global_transform.basis.get_euler()
	_yaw_deg = rad_to_deg(euler.y)
	_pitch_deg = rad_to_deg(euler.x)
	_pitch_deg = clamp(_pitch_deg, min_pitch_deg, max_pitch_deg)
	_apply_rot()

	# Clamp initial arm length
	spring_length = clampf(spring_length, min_zoom, max_zoom)

func _unhandled_input(event: InputEvent) -> void:
	if(!IS_LOCKED):
		# Start/stop orbit mode with middle mouse (or cam_orbit action)
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed and not _orbiting:
				_orbiting = true
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			elif not event.pressed and _orbiting:
				_orbiting = false
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

		# Zoom with mouse wheel
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
				spring_length = clampf(spring_length - zoom_speed, min_zoom, max_zoom)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
				spring_length = clampf(spring_length + zoom_speed, min_zoom, max_zoom)

		# Mouse look while orbiting
		if _orbiting and event is InputEventMouseMotion:
			_yaw_deg -= event.relative.x * horizontal_sensitivity
			var dy = event.relative.y * vertical_sensitivity
			if invert_y:
				_pitch_deg += dy
			else:
				_pitch_deg -= dy
			_pitch_deg = clamp(_pitch_deg, min_pitch_deg, max_pitch_deg)
			_apply_rot()

	# Reset camera orientation (optional)
	#if event.is_action_pressed("cam_reset"):
	#	_start_reset_to_player_forward()

func _physics_process(delta: float) -> void:
	if(!IS_LOCKED):
		# Optional: support controller right stick look even without middle mouse.
		var look_x := Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left", true)
		var look_y := Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down", true)
		if abs(look_x) > 0.01 or abs(look_y) > 0.01:
			_yaw_deg -= look_x * gamepad_look_speed * delta
			if invert_y:
				_pitch_deg += look_y
			else:
				_pitch_deg -= look_y
			_pitch_deg = clamp(_pitch_deg, min_pitch_deg, max_pitch_deg)
			_apply_rot()

		# Smooth reset if triggered
		if _resetting:
			_reset_time += delta
			var t := clampf(_reset_time / max(smooth_reset_time, 0.001), 0.0, 1.0)
			var slerped := _reset_from_basis.slerp(_reset_to_basis, t)
			global_transform.basis = slerped
			if t >= 1.0:
				_resetting = false
				# Re-derive yaw/pitch from the final orientation
				var e = global_transform.basis.get_euler()
				_yaw_deg = rad_to_deg(e.y)
				_pitch_deg = clamp(rad_to_deg(e.x), min_pitch_deg, max_pitch_deg)

func _apply_rot() -> void:
	# We rotate ONLY this SpringArm node in place. Because it’s a child
	# of the player (or CameraRig under player), it “orbits” the parent.
	var yaw := deg_to_rad(_yaw_deg)
	var pitch := deg_to_rad(_pitch_deg)

	var rot := Basis()
	# Order: yaw around global up (Y), then pitch around local X (YXZ)
	rot = Basis(Vector3(0,1,0), yaw) * Basis(Vector3(1,0,0), pitch)

	# Keep position; set orientation
	var t := global_transform
	t.basis = rot.orthonormalized()
	global_transform = t

func _start_reset_to_player_forward() -> void:
	# Aim camera to match the parent’s facing (keeps current pitch).
	var parent_node := get_parent()
	if parent_node == null:
		return

	_resetting = true
	_reset_time = 0.0
	_reset_from_basis = global_transform.basis

	# Build a "target" basis that looks along the parent’s +Z (or -Z depending on your game).
	# Here we align yaw to parent’s basis while preserving pitch.
	var parent_yaw = parent_node.global_transform.basis.get_euler_yxz().y
	var target := Basis(Vector3(0,1,0), parent_yaw) * Basis(Vector3(1,0,0), deg_to_rad(_pitch_deg))
	_reset_to_basis = target.orthonormalized()
