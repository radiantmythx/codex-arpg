class_name Affix
extends Resource

# Runtime affix attached to an item. Affix instances are generated from
# `AffixDefinition` resources and store the rolled tier and numeric value. The
# dictionaries hold the actual stat bonuses applied by `Stats`.

@export var name: String = ""
@export var tier: int = 1
@export var description: String = ""
@export var main_stat_bonuses: Dictionary = {}  # key: Stats.MainStat, value: float
@export var stat_bonuses: Dictionary = {}  # key: String, value: float
@export var flags: Array[String] = []


func get_description() -> String:
	return "T%s %s" % [tier, description]
