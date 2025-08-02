class_name Stats
extends Resource

# Holds the core and derived statistics for an actor. Affixes are applied to
# this resource and contribute bonuses to the base values. The system is fully
# data driven – new stats can be introduced simply by referencing a new
# `stat_key` in an `AffixDefinition`.

# Enumeration of the four primary stats used throughout the game.
# Fortune has been renamed to Luck to better match traditional RPG terminology.
enum MainStat { BODY, MIND, SOUL, LUCK }

# Base values before equipment or other bonuses are applied.
var base_main := {
        MainStat.BODY: 0,
        MainStat.MIND: 0,
        MainStat.SOUL: 0,
        MainStat.LUCK: 0,
}

# Base numeric values before affixes are applied.  These can be modified by
# both additive and percentage based affixes.
var base_damage: float = 1.0
var base_move_speed: float = 5.0
var base_defense: float = 0.0
var base_max_health: float = 0.0
var base_max_mana: float = 0.0
var base_health_regen: float = 0.0
var base_mana_regen: float = 0.0

# Internal list of affixes currently affecting the stats.
var _affixes: Array[Affix] = []

# Cached bonuses calculated from the affix list. `_main_flat` and `_stat_flat`
# store additive bonuses while `_main_inc` and `_stat_inc` hold percentage
# based "increased" bonuses.
var _main_flat := {
        MainStat.BODY: 0.0,
        MainStat.MIND: 0.0,
        MainStat.SOUL: 0.0,
        MainStat.LUCK: 0.0,
}
var _main_inc := {
        MainStat.BODY: 0.0,
        MainStat.MIND: 0.0,
        MainStat.SOUL: 0.0,
        MainStat.LUCK: 0.0,
}
var _stat_flat: Dictionary = {}
var _stat_inc: Dictionary = {}
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
        _main_flat = {
                MainStat.BODY: 0.0,
                MainStat.MIND: 0.0,
                MainStat.SOUL: 0.0,
                MainStat.LUCK: 0.0,
        }
        _main_inc = {
                MainStat.BODY: 0.0,
                MainStat.MIND: 0.0,
                MainStat.SOUL: 0.0,
                MainStat.LUCK: 0.0,
        }
        _stat_flat.clear()
        _stat_inc.clear()
        _flags.clear()
        for aff in _affixes:
                for f in aff.flags:
                        _flags[f] = true
        for aff in _affixes:
                for k in aff.main_stat_bonuses:
                        var target := k
                        if _flags.has("body_to_mind") and k == MainStat.BODY:
                                target = MainStat.MIND
                        _main_flat[target] = _main_flat.get(target, 0) + aff.main_stat_bonuses[k]
                for key in aff.stat_bonuses:
                        var value: float = aff.stat_bonuses[key]
                        if key.ends_with("_inc"):
                                var base_key := key.substr(0, key.length() - 4)
                                match base_key:
                                        "body":
                                                _main_inc[MainStat.BODY] = _main_inc.get(MainStat.BODY, 0.0) + value
                                        "mind":
                                                _main_inc[MainStat.MIND] = _main_inc.get(MainStat.MIND, 0.0) + value
                                        "soul":
                                                _main_inc[MainStat.SOUL] = _main_inc.get(MainStat.SOUL, 0.0) + value
                                        "luck":
                                                _main_inc[MainStat.LUCK] = _main_inc.get(MainStat.LUCK, 0.0) + value
                                        _:
                                                _stat_inc[base_key] = _stat_inc.get(base_key, 0.0) + value
                        else:
                                _stat_flat[key] = _stat_flat.get(key, 0.0) + value


# -- Query helpers ----------------------------------------------------------


func _compute_main(base: float, stat: MainStat) -> float:
        var flat := _main_flat.get(stat, 0.0)
        var inc := _main_inc.get(stat, 0.0)
        return (base + flat) * (1.0 + inc / 100.0)


func _compute_stat(base: float, key: String) -> float:
        var flat := _stat_flat.get(key, 0.0)
        var inc := _stat_inc.get(key, 0.0)
        return (base + flat) * (1.0 + inc / 100.0)


func get_main(stat: MainStat) -> int:
        return int(_compute_main(base_main.get(stat, 0), stat))


func get_damage() -> float:
        return _compute_stat(base_damage, "damage")


func get_move_speed() -> float:
        return _compute_stat(base_move_speed, "move_speed")


func get_defense() -> float:
        return _compute_stat(base_defense, "defense")


func get_max_health() -> float:
        return _compute_stat(base_max_health, "max_health")


func get_max_mana() -> float:
        return _compute_stat(base_max_mana, "max_mana")


func get_health_regen() -> float:
        return _compute_stat(base_health_regen, "health_regen")


func get_mana_regen() -> float:
        return _compute_stat(base_mana_regen, "mana_regen")


func get_misc(stat: String) -> float:
        # Allows retrieval of unique numeric stats such as "life_steal".
        return _compute_stat(0.0, stat)
