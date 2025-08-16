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
@export var item_type: String = ""

# Name of the equipment slot this item fits in. Leave empty for non-equipable
# items such as consumables.  Example values: "weapon", "armor", "ring".
@export var equip_slot: String = ""

# When true, equipping this item will hide the player's hair model if present.
# Helmets and hoods can toggle this flag so the hair is temporarily removed
# while the item is worn.  The hair will automatically reappear when the
# item is unequipped.  Exposed via the inspector for easy configuration in
# Godot 4.4.
@export var hide_hair: bool = false

# Pool of definitions this item may roll affixes from when crafted.
@export var affix_pool: Array[AffixDefinition] = []

# Optional groups of affixes that can be shared across multiple items.
@export var affix_groups: Array[AffixGroup] = []

# Affixes currently attached to this item.
@export var affixes: Array[Affix] = []

# Optional 3D model representing the item when equipped.  The scene should
# contain a `MeshInstance3D` (for armor it may contain multiple meshes) and is
# instanced and attached to the player when this item is equipped. Leave null
# for items that do not have a visual representation.
@export var model: PackedScene

# Transform applied to `model` when attached to the player.  This allows the
# orientation and offset to be tweaked in the inspector so the item aligns
# correctly with the hand or body.  The transform is relative to the attach
# point (e.g. the character's hand bone).
@export var equip_transform: Transform3D = Transform3D.IDENTITY
@export var equip_position: Vector3 = Vector3.ZERO
@export var equip_rotation_rads:Vector3 = Vector3.ZERO


func reroll_affixes() -> bool:
		# Clears existing affixes and rolls new ones from `affix_pool`.
		affixes.clear()
		var pool: Array[AffixDefinition] = _get_all_affix_definitions()
		if pool.is_empty():
				return false
		for i in range(MAX_AFFIXES):
				if pool.is_empty():
						break
				if i < 3 or randf() < 0.5:
						var def: AffixDefinition = pool.pick_random()
						pool.erase(def)
						var tier := _roll_weighted_tier(def.get_tier_count())
						affixes.append(def.roll(tier))
		return not affixes.is_empty()


func temper_random_affix() -> bool:
		# Rerolls the tier of a random existing affix.
		if affixes.is_empty():
				return false
		var index := randi_range(0, affixes.size() - 1)
		var current: Affix = affixes[index]
		var def := _find_affix_definition(current.name)
		if not def:
				return false
		var tier := _roll_weighted_tier(def.get_tier_count())
		affixes[index] = def.roll(tier)
		return true


func remove_random_affix() -> bool:
		# Removes one random affix from the item.
		if affixes.is_empty():
				return false
		var index := randi_range(0, affixes.size() - 1)
		affixes.remove_at(index)
		return true


func add_random_affix() -> bool:
		# Adds a new random affix if capacity allows.
		if affixes.size() >= MAX_AFFIXES:
				return false
		var pool: Array[AffixDefinition] = _get_all_affix_definitions()
		for a in affixes:
				for d in pool.duplicate():
						if d.name == a.name:
								pool.erase(d)
		if pool.is_empty():
				return false
		var def: AffixDefinition = pool.pick_random()
		var tier := _roll_weighted_tier(def.get_tier_count())
		affixes.append(def.roll(tier))
		return true


func clear_affixes() -> bool:
		# Removes all affixes from the item.
		if affixes.is_empty():
				return false
		affixes.clear()
		return true


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


func _get_all_affix_definitions() -> Array[AffixDefinition]:
		var pool: Array[AffixDefinition] = []
		pool.append_array(affix_pool)
		for g in affix_groups:
				if g:
						pool.append_array(g.affixes)
		return pool


func _find_affix_definition(n: String) -> AffixDefinition:
		for d in _get_all_affix_definitions():
				if d.name == n:
						return d
		return null
