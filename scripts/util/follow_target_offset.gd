extends Node3D

@export var follow_target_path: NodePath  # set to your Player (or Player root)

var _follow_target: Node3D
var _offset: Vector3

func _ready() -> void:
	set_as_top_level(true)  # stops inheriting parent rotation/scale
	if follow_target_path != NodePath():
		_follow_target = get_node(follow_target_path)
	_offset = _follow_target.global_position - global_position
	# keep your existing init (yaw/pitch, zoom, etc.)

func _physics_process(delta: float) -> void:
	if _follow_target:
		var t := 1.0 - pow(0.001, delta)  # ~crit damp
		global_position = global_position.lerp(_follow_target.global_position - _offset, t)
	# keep your orbit input + _apply_rot() here (this rotation is now independent)
