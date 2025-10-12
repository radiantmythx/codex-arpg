extends Area3D

@export var border_mesh:Node3D

func _on_body_exited(body):
	if body.is_in_group("player"):
		border_mesh.visible = true
	
func _on_body_entered(body):
	if body.is_in_group("player"):
		border_mesh.visible = false
