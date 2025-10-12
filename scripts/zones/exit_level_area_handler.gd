extends Area3D



func _on_body_exited(body):
	if body.is_in_group("player"):
		print("Player exited, moving to map")
