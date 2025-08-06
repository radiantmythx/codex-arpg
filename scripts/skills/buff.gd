class_name Buff
extends Resource

@export var duration: float = 0.0
@export var main_stat_bonuses: Dictionary = {}
@export var stat_bonuses: Dictionary = {}
@export var flags: Array[String] = []

func _create_affix() -> Affix:
	var a := Affix.new()
	a.main_stat_bonuses = main_stat_bonuses.duplicate()
	a.stat_bonuses = stat_bonuses.duplicate()
	a.flags = flags.duplicate()
	return a
