class_name ModifierNode
extends PassiveNode

@export var affix: Affix
var _instance: Affix = null

func apply_effect(player) -> void:
	if player and player.stats and affix:
		_instance = affix.duplicate()
		player.stats.apply_affix(_instance)

func remove_effect(player) -> void:
	if player and player.stats and _instance:
		player.stats.remove_affix(_instance)
		_instance = null
