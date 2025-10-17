extends Node3D

@export var LevelContainer:Node3D
@export var PlayerContainer:PlayerContainer

@export var skip_character_creation:bool = true
@export var skip_title_screen:bool = true

@export var title_screen_scene:PackedScene
@export var character_creation_scene:PackedScene

func _ready():
	GlobalPlayerHandler._initialize_player(PlayerContainer)
	WorldGrid.set_scene_hosts(LevelContainer, PlayerContainer)
	if(skip_title_screen):
		load_main_level()
	else:
		PlayerContainer.visible = false
		PlayerContainer.disable_player_cam()
		WorldGrid.load_special_level(title_screen_scene)
		

func load_main_level():
	print("Loading level!")
	WorldGrid.load_level(Vector2i(0, 0))
