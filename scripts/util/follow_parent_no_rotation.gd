extends Node3D

@onready var parent3d: Node3D = get_parent()
@export var world_offset := Vector3.ZERO  # optional

func _process(_dt):
	if parent3d:
		global_position = parent3d.global_position + world_offset
