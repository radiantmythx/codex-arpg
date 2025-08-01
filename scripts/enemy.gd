extends CharacterBody3D

@export var max_health: int = 3
var current_health: int

signal died

func _ready() -> void:
	current_health = max_health

func take_damage(amount: int) -> void:
	print("Ow! Took ", amount)
	current_health -= amount
	if current_health <= 0:
		die()

func die() -> void:
	emit_signal("died")
	queue_free()
