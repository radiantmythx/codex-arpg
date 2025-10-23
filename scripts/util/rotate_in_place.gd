extends Node3D

@export var rotation_speed_deg: Vector3 = Vector3(0, 90, 0)
# rotation speed in degrees per second for X, Y, Z axes

func _process(delta: float) -> void:
	var rot_rads := Vector3(
		deg_to_rad(rotation_speed_deg.x),
		deg_to_rad(rotation_speed_deg.y),
		deg_to_rad(rotation_speed_deg.z)
	) * delta

	rotate_x(rot_rads.x)
	rotate_y(rot_rads.y)
	rotate_z(rot_rads.z)
