class_name Item
extends Resource

# Maximum number of affixes an item may hold.
const MAX_AFFIXES := 6

# Basic item resource used by the inventory and equipment systems.
# Items may represent consumables or equippable gear depending on their
# configuration.  Equippable items expose an `equip_slot` and a list of
# `Affix` instances that describe bonuses the item grants when equipped.

@export var item_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var max_stack: int = 1

# Name of the equipment slot this item fits in. Leave empty for non-equipable
# items such as consumables.  Example values: "weapon", "armor", "ring".
@export var equip_slot: String = ""

# Pool of definitions this item may roll affixes from when crafted.
@export var affix_pool: Array[AffixDefinition] = []

# Affixes currently attached to this item.
@export var affixes: Array[Affix] = []


func reroll_affixes() -> void:
		# Clears existing affixes and rolls new ones from `affix_pool`.
		affixes.clear()
		if affix_pool.is_empty():
				return
		var pool := affix_pool.duplicate()
		for i in range(MAX_AFFIXES):
				if pool.is_empty():
						break
				if i < 3 or randf() < 0.5:
						var def: AffixDefinition = pool.pick_random()
						pool.erase(def)
						var tier := _roll_weighted_tier(def.get_tier_count())
						affixes.append(def.roll(tier))


func _roll_weighted_tier(count: int) -> int:
		# Returns a tier index using linear weights where T1 is the best (and
		# rarest) roll. Higher tier numbers have larger weights making them more
		# common.
		var total := 0.0
		for i in range(1, count + 1):
				total += i
		var r := randf() * total
		var cumulative := 0.0
		for i in range(1, count + 1):
				cumulative += i
				if r < cumulative:
						return i
		return count


func get_affix_text() -> String:
	# Returns a multi-line string listing all affixes on the item.
	var lines: Array[String] = []
	for a in affixes:
		lines.append(a.get_description())
	return "\n".join(lines)
