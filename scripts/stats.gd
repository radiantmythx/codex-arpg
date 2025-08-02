extends Resource
class_name Stats

# Holds the core and derived statistics for an actor.  The class exposes helper
# functions to query values after all affix modifiers have been applied.  This
# keeps the logic for calculating final damage, movement speed and defenses in a
# single place.

# Enumeration of the four primary stats used throughout the game.
enum MainStat { BODY, MIND, SOUL, FORTUNE }

# Base values before equipment or other bonuses are applied.
var base_main := {
    MainStat.BODY: 0,
    MainStat.MIND: 0,
    MainStat.SOUL: 0,
    MainStat.FORTUNE: 0,
}

var base_damage: float = 1.0
var base_move_speed: float = 5.0
var base_defense: float = 0.0

# Internal list of affixes currently affecting the stats.
var _affixes: Array[Affix] = []

# -- Affix management -------------------------------------------------------

func apply_affix(affix: Affix) -> void:
    # Adds an affix to the active list if it is not already present.
    if affix and not _affixes.has(affix):
        _affixes.append(affix)

func remove_affix(affix: Affix) -> void:
    _affixes.erase(affix)

# -- Query helpers ----------------------------------------------------------

func get_main(stat: MainStat) -> int:
    var value: int = base_main.get(stat, 0)
    for affix in _affixes:
        value += affix.stat_modifiers.get(stat, 0)
    return value

func get_damage() -> float:
    var value: float = base_damage
    for affix in _affixes:
        value += affix.damage_bonus
    return value

func get_move_speed() -> float:
    var value: float = base_move_speed
    for affix in _affixes:
        value += affix.move_speed_bonus
    return value

func get_defense() -> float:
    var value: float = base_defense
    for affix in _affixes:
        value += affix.defense_bonus
    return value
