extends Node3D

@export var LevelContainer:Node3D
@export var PlayerContainer:Node3D

func _ready():
	WorldGrid.set_scene_hosts(LevelContainer, PlayerContainer)
	print("Loading level!")
	WorldGrid.load_level(Vector2i(0, 0))
