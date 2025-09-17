extends Node3D

@export var anim_player:AnimationPlayer

func _ready():
	anim_player.play("pSystem")
