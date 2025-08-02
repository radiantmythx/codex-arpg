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
	var count := randi_range(1, min(MAX_AFFIXES, pool.size()))
	for i in range(count):
		var def: AffixDefinition = pool.pick_random()
		pool.erase(def)
		var tier := randi_range(1, def.get_tier_count())
		affixes.append(def.roll(tier))


func get_affix_text() -> String:
	# Returns a multi-line string listing all affixes on the item.
	var lines: Array[String] = []
	for a in affixes:
		lines.append(a.get_description())
	return "\n".join(lines)
