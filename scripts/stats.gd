class_name Stats
extends Resource

# Holds the core and derived statistics for an actor. Affixes are applied to
# this resource and contribute bonuses to the base values. The system is fully
# data driven – new stats can be introduced simply by referencing a new
# `stat_key` in an `AffixDefinition`.

# Enumeration of the four primary stats used throughout the game.
# Fortune has been renamed to Luck to better match traditional RPG terminology.
enum MainStat { BODY, MIND, SOUL, LUCK }

# Enumeration of all elemental and physical damage types handled by the
# combat system.  These values are used both for offensive damage rolls and
# defensive resistances.
enum DamageType { PHYSICAL, SOLAR, ICE, ELECTRIC, HOLY, UNHOLY }

# Mapping from `DamageType` to string tokens used by the affix/stat system.
const DAMAGE_TYPE_KEYS = {
	DamageType.PHYSICAL: "physical",
	DamageType.SOLAR: "solar",
	DamageType.ICE: "ice",
	DamageType.ELECTRIC: "electric",
	DamageType.HOLY: "holy",
	DamageType.UNHOLY: "unholy",
}
const DAMAGE_TYPES = [DamageType.PHYSICAL, DamageType.SOLAR, DamageType.ICE, DamageType.ELECTRIC, DamageType.HOLY, DamageType.UNHOLY]

# Base values before equipment or other bonuses are applied.
var base_main := {
	MainStat.BODY: 0,
	MainStat.MIND: 0,
	MainStat.SOUL: 0,
	MainStat.LUCK: 0,
}

# Base numeric values before affixes are applied.  These can be modified by
# both additive and percentage based affixes.
var base_damage: Dictionary = {
	DamageType.PHYSICAL: 1.0,
	DamageType.SOLAR: 0.0,
	DamageType.ICE: 0.0,
	DamageType.ELECTRIC: 0.0,
	DamageType.HOLY: 0.0,
	DamageType.UNHOLY: 0.0,
}
var base_move_speed: float = 5.0
var base_defense: float = 0.0
var base_max_health: float = 0.0
var base_max_mana: float = 0.0
var base_health_regen: float = 0.0
var base_mana_regen: float = 0.0
var base_armor: float = 0.0
var base_evasion: float = 0.0
var base_aoe: float = 1.0
var base_resistance: Dictionary = {
	DamageType.PHYSICAL: 0.0,
	DamageType.SOLAR: 0.0,
	DamageType.ICE: 0.0,
	DamageType.ELECTRIC: 0.0,
DamageType.HOLY: 0.0,
	DamageType.UNHOLY: 0.0,
}
var base_max_energy_shield: float = 0.0
var base_energy_shield_regen: float = 0.0
var base_energy_shield_recharge_delay: float = 0.0

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
	for affi in _affixes:
		for f in affi.flags:
			_flags[f] = true
	for aff in _affixes:
		for k in aff.main_stat_bonuses:
			var target = k
			if _flags.has("body_to_mind") and k == MainStat.BODY:
				target = MainStat.MIND
			_main_flat[target] = _main_flat.get(target, 0) + aff.main_stat_bonuses[k]
		for key in aff.stat_bonuses:
			var value: float = aff.stat_bonuses[key]
			if key.ends_with("_inc"):
				var base_key = key.substr(0, key.length() - 4)
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
	var flat = _main_flat.get(stat, 0.0)
	var inc = _main_inc.get(stat, 0.0)
	return (base + flat) * (1.0 + inc / 100.0)


func _compute_stat(base: float, key: String) -> float:
	var flat = _stat_flat.get(key, 0.0)
	var inc = _stat_inc.get(key, 0.0)
	return (base + flat) * (1.0 + inc / 100.0)

func _compute_stat_tagged(base: float, key: String, tags: Array[String]) -> float:
	var flat = _stat_flat.get(key, 0.0)
	var inc = _stat_inc.get(key, 0.0)
	for t in tags:
		var tag_key = "%s_%s" % [key, t.to_lower()]
		flat += _stat_flat.get(tag_key, 0.0)
		inc += _stat_inc.get(tag_key, 0.0)
	return (base + flat) * (1.0 + inc / 100.0)


func get_main(stat: MainStat) -> int:
	return int(_compute_main(base_main.get(stat, 0), stat))


func get_damage(damage_type: DamageType = DamageType.PHYSICAL, tags: Array[String] = []) -> float:
	var key = "%s_damage" % DAMAGE_TYPE_KEYS[damage_type]
	return _compute_stat_tagged(base_damage.get(damage_type, 0.0), key, tags)

func get_all_damage(tags: Array[String] = []) -> Dictionary:
	return compute_damage({}, tags)


func compute_damage(extra_base: Dictionary, tags: Array[String] = []) -> Dictionary:
		# Calculates total damage per type using the actor's base damage
		# plus any additional `extra_base` provided by skills. Values in
		# `extra_base` should be Vector2 ranges representing min/max
		# damage to roll.
	var result: Dictionary = {}
	for dt in DAMAGE_TYPES:
		var base_val: float = base_damage.get(dt, 0.0)
		if extra_base.has(dt):
			var val = extra_base[dt]
			if typeof(val) == TYPE_VECTOR2:
				base_val += randf_range(val.x, val.y)
			else:
				base_val += float(val)
		var key = "%s_damage" % DAMAGE_TYPE_KEYS[dt]
		result[dt] = _compute_stat_tagged(base_val, key, tags)
	return result


func get_move_speed() -> float:
	return _compute_stat(base_move_speed, "move_speed")


func get_defense() -> float:
	return _compute_stat(base_defense, "defense")

func get_resistance(damage_type: DamageType) -> float:
	var key = "%s_resistance" % DAMAGE_TYPE_KEYS[damage_type]
	return _compute_stat(base_resistance.get(damage_type, 0.0), key)

func get_armor() -> float:
	return _compute_stat(base_armor, "armor")

func get_evasion() -> float:
	return _compute_stat(base_evasion, "evasion")

func get_aoe_multiplier() -> float:
	return _compute_stat(base_aoe, "aoe")


func get_max_health() -> float:
	return _compute_stat(base_max_health, "max_health")


func get_max_mana() -> float:
	return _compute_stat(base_max_mana, "max_mana")

func get_max_energy_shield() -> float:
	return _compute_stat(base_max_energy_shield, "max_energy_shield")


func get_health_regen() -> float:
	return _compute_stat(base_health_regen, "health_regen")

func get_energy_shield_regen() -> float:
	return _compute_stat(base_energy_shield_regen, "energy_shield_regen")

func get_energy_shield_recharge_delay() -> float:
	return _compute_stat(base_energy_shield_recharge_delay, "energy_shield_recharge_delay")


func get_mana_regen() -> float:
	return _compute_stat(base_mana_regen, "mana_regen")


func get_misc(stat: String) -> float:
		# Allows retrieval of unique numeric stats such as "life_steal".
	return _compute_stat(0.0, stat)
