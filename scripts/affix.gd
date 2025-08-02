extends Resource
class_name Affix

# Describes a single modifier that can be attached to an item.  Affixes are
# applied to the player's Stats when the containing item is equipped.
#
# `stat_modifiers` uses keys from `Stats.MainStat` to modify the core stats
# BODY, MIND, SOUL and FORTUNE.

@export var stat_modifiers: Dictionary = {}
@export var damage_bonus: float = 0.0
@export var move_speed_bonus: float = 0.0
@export var defense_bonus: float = 0.0
