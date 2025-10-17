extends Control

@export var character_creation_scene:PackedScene

func _on_load_game_button_pressed():
	WorldGrid.load_level(Vector2i(0, 0))
	WorldGrid.show_player_container(true)
	WorldGrid.enable_player_ui(true)


func _on_new_game_button_pressed():
	WorldGrid.load_special_level(character_creation_scene)
	WorldGrid.show_player_container(true)
	WorldGrid.enable_player_ui(false)
	GlobalPlayerHandler.freeze_player(true)
	GlobalPlayerHandler.freeze_player_springarm(true)
	GlobalPlayerHandler.set_visual_player_rotation_override(180)
