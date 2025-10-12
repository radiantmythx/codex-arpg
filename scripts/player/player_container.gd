extends Node3D
class_name PlayerContainer

@export var player:CharacterBody3D

func reset_player_position():
	player.position = Vector3(0, 0 ,0)
