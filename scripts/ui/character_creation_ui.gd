extends Control


func _on_play_button_pressed():
	WorldGrid.load_level(Vector2i(0, 0))
	WorldGrid.show_player_container(true)
	WorldGrid.enable_player_ui(true)
	GlobalPlayerHandler.freeze_player(false)
	GlobalPlayerHandler.freeze_player_springarm(false)
