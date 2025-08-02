class_name Stats
extends Resource

# Holds the core and derived statistics for an actor. Affixes are applied to
# this resource and contribute bonuses to the base values. The system is fully
# data driven – new stats can be introduced simply by referencing a new
# `stat_key` in an `AffixDefinition`.

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

# Cached bonuses calculated from the affix list.
var _main_bonus := {
	MainStat.BODY: 0.0,
	MainStat.MIND: 0.0,
	MainStat.SOUL: 0.0,
	MainStat.FORTUNE: 0.0,
}
var _stat_bonus: Dictionary = {}
var _flags: Dictionary = {}

# -- Affix management -------------------------------------------------------


func apply_affix(affix: Affix) -> void:
	# Adds an affix to the active list and recalculates bonuses.
	if affix and not _affixes.has(affix):
		_affixes.append(affix)
		_recalculate_bonuses()


func remove_affix(affix: Affix) -> void:
	_affixes.erase(affix)
	_recalculate_bonuses()


func _recalculate_bonuses() -> void:
	# Rebuilds cached bonus dictionaries based on the current affix list.
	_main_bonus = {
		MainStat.BODY: 0.0,
		MainStat.MIND: 0.0,
		MainStat.SOUL: 0.0,
		MainStat.FORTUNE: 0.0,
	}
	_stat_bonus.clear()
	_flags.clear()
	for aff in _affixes:
		for f in aff.flags:
			_flags[f] = true
	for aff in _affixes:
		for k in aff.main_stat_bonuses:
			var target := k
			if _flags.has("body_to_mind") and k == MainStat.BODY:
				target = MainStat.MIND
			_main_bonus[target] = _main_bonus.get(target, 0) + aff.main_stat_bonuses[k]
		for key in aff.stat_bonuses:
			_stat_bonus[key] = _stat_bonus.get(key, 0.0) + aff.stat_bonuses[key]


# -- Query helpers ----------------------------------------------------------


func get_main(stat: MainStat) -> int:
	return int(base_main.get(stat, 0) + _main_bonus.get(stat, 0))


func get_damage() -> float:
	return base_damage + _stat_bonus.get("damage", 0.0)


func get_move_speed() -> float:
	return base_move_speed + _stat_bonus.get("move_speed", 0.0)


func get_defense() -> float:
	return base_defense + _stat_bonus.get("defense", 0.0)


func get_misc(stat: String) -> float:
	# Allows retrieval of unique numeric stats such as "life_steal".
	return _stat_bonus.get(stat, 0.0)
