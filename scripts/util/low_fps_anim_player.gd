extends AnimationPlayer

@export var target_fps: float = 8.0
@export var force_nearest_interpolation: bool = true  # set false if you want track interpolation left as-is

var _accum := 0.0
var _frame_time := 0.0

func _ready() -> void:
	_frame_time = 1.0 / max(target_fps, 0.001)

	# Stop automatic time progression; we'll step manually.
	speed_scale = 0.0

	# Optionally force all tracks in the current animation to "Nearest" (no interpolation).
	# Do this per animation as needed (call again after switching animations if you want all of them forced).
	if force_nearest_interpolation and current_animation != StringName():
		_force_current_animation_nearest()

func _process(delta: float) -> void:
	if not is_playing():
		return

	_accum += delta
	if _accum >= _frame_time:
		_accum -= _frame_time

		var pos := current_animation_position + _frame_time
		var len := current_animation_length

		if len > 0.0:
			if pos >= len:
				# Respect the clip's loop flag.
				if current_animation:
					pos = fmod(pos, len)
				else:
					pos = len
					seek(pos, true)
					stop()
					return

		# Snap to the new time with updates applied immediately (no blending).
		seek(pos, true)

# Optional helper: call this after changing current animation, if you want all tracks discrete.
func _force_current_animation_nearest() -> void:
	var anim: Animation = get_animation(current_animation)
	if anim == null:
		return
	for i in anim.get_track_count():
		var ttype := anim.track_get_type(i)
		# Value/Transform tracks support interpolation control.
		# Use "nearest" so there is no tweening between keys.
		anim.track_set_interpolation_type(i, Animation.INTERPOLATION_NEAREST)
