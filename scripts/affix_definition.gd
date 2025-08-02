class_name AffixDefinition
extends Resource

# Data-driven definition of an affix type. AffixDefinitions describe the
# possible tiers, value ranges and stat affected by an affix.
#
# `tiers` is an Array of Vector2 where `x` is the minimum roll and `y` is the
# maximum roll for that tier. Tier indexing starts at 1.
#
# `stat_key` determines which stat in `Stats` this affix modifies. Examples:
#   "damage"       -> affects Stats.get_damage()
#   "move_speed"   -> affects Stats.get_move_speed()
#   "defense"      -> affects Stats.get_defense()
#   "life_steal"   -> retrievable through Stats.get_misc("life_steal")
#
# `main_stat` can be used to modify the primary stats defined in
# Stats.MainStat.  Leave `main_stat` as -1 when the affix modifies one of the
# string based `stat_key` values.
#
# `flags` may contain special keywords that toggle unique behaviour when the
# affix is applied. For example, a flag of "body_to_mind" will cause all BODY
# bonuses to be applied to MIND instead.
#
# `description` is a template string used to show the rolled value. The token
# `{value}` will be replaced with the numeric roll when generating a tooltip.

@export var name: String = ""
@export var description: String = ""
@export var stat_key: String = ""
@export var main_stat: int = -1
@export var tiers: Array[Vector2] = []
@export var flags: Array[String] = []


func get_tier_count() -> int:
	return tiers.size()


func roll(tier: int) -> Affix:
	# Rolls a new Affix instance for the given tier.
	tier = clamp(tier, 1, tiers.size())
	var range: Vector2 = tiers[tier - 1]
	var value := randf_range(range.x, range.y)
	var affix := Affix.new()
	affix.name = name
	affix.tier = tier
	var text := description
	if text.find("{value}") != -1:
		text = description.format({"value": _format_value(value)})
	affix.description = text
	if main_stat != -1:
		affix.main_stat_bonuses[main_stat] = value
	elif stat_key != "":
		affix.stat_bonuses[stat_key] = value
	affix.flags = flags.duplicate()
	return affix


func _format_value(v: float) -> String:
	# Helper to trim trailing zeros for nicer tooltip text.
	if abs(v - int(v)) < 0.01:
		return str(int(v))
	return str(round(v, 2))
