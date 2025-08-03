class_name Rune
extends Item

# Types of runes available in the game.
# Runes are combined in pairs to generate skills.
# The order of the enum is important for mapping combinations.
# Ensure new types are appended to avoid changing existing indexes.

enum RuneType { STRIKE, BUFF, AREA, TIME }

@export var rune_type: RuneType = RuneType.STRIKE
