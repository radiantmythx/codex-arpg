extends Node3D
class_name PlayerContainer

@export var player:CharacterBody3D
@export var player_cam:Camera3D
@export var player_springarm:SpringArm3D
@export var ui_nodes:Array[CanvasLayer]

func get_player():
	return player

func get_player_springarm():
	return player_springarm
	
func get_player_cam():
	return player_cam

func reset_player_position():
	player.global_position = global_position
	player.position = Vector3(0, 0, 0)

func disable_player_cam():
	player_cam.current = false
	disable_player_ui()
	
func enable_player_cam():
	player_cam.current = true
	enable_player_ui()
	
func disable_player_ui():
	for c in ui_nodes:
		c.visible = false

func enable_player_ui():
	for c in ui_nodes:
		c.visible = true
		
func add_player_race_visual(vis: PackedScene) -> void:
	var visual := vis.instantiate()
	player.get_race_visuals().add_child(visual) # must be in the same tree before resolving paths

	var skel: Skeleton3D = player.get_skeleton()
	_retarget_to_skeleton(visual, skel)


func _retarget_to_skeleton(node: Node, skel: Skeleton3D) -> void:
	for child in node.get_children():
		# Handle meshes
		if child is MeshInstance3D:
			# Only matters if the mesh is skinned (has a Skin resource)
			child.skeleton = child.get_path_to(skel)
				
		# Handle nested nodes recursively
		_retarget_to_skeleton(child, skel)

func reset_player_race_visuals():
	player.reset_race_visuals()
	
func set_surface_albedo(surface_name: String, color: Color):
	player.set_surface_albedo_and_propagate(surface_name, color)
	
func get_player_race() -> String:
	return player.player_race
	
func set_player_race(race:String):
	player.player_race = race
	
func force_player_oneshot_and_return(animStateName:String):
	player.play_state_once_then_return(animStateName)
	
func force_player_oneshot_and_idle(animStateName:String):
	player.play_state_once_then_return(animStateName, true)
	
func set_player_bodymesh_blendshape(blendShape:String, amount:float):
	player.set_bodymesh_blendshape(blendShape, amount)
