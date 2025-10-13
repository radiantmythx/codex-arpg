# Compass.gd
extends Control
class_name Compass

@export var dial_path: NodePath            # TextureRect of the dial (with N/E/S/W printed)
@export var camera_rig_path: NodePath      # Your SpringArm3D (this script you posted)

var _dial: TextureRect
var _rig: Node3D

func _ready() -> void:
	_dial = get_node(dial_path) as TextureRect
	_rig = get_node(camera_rig_path) as Node3D
	# Make sure rotation happens around center:
	await get_tree().process_frame
	_dial.pivot_offset = _dial.size * 0.5

func _process(_delta: float) -> void:
	if _rig == null:
		return
	# Forward/look direction = -Z in Godot
	var f: Vector3 = -_rig.global_transform.basis.z
	# Heading: 0° north (+Z), 90° east (+X), etc.
	var heading_deg := rad_to_deg(atan2(f.x, f.z))
	# Rotate dial opposite the heading so the correct letter is at top.
	_dial.rotation_degrees = heading_deg
