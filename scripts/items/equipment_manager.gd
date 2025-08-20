extends Node
class_name EquipmentManager

# Handles equipping and unequipping of items and applies their affixes to a
# `Stats` instance. The manager supports multiple slots of the same type (e.g.
# two "ring" slots) and emits a signal whenever a slot changes.

signal slot_changed(slot: String, index: int, item: Item)

@export var stats: Stats

# Dictionary mapping slot type -> array of items. Duplicate slot types create
# additional entries in the array so we can have, for example, two "ring" slots.
var _slots: Dictionary = {}

func set_slots(names: Array) -> void:
		# Initializes available equipment slots. Each entry in `names` is a slot
		# type ("weapon", "ring", etc.). Duplicate entries create multiple slots
		# of the same type.
		for n in names:
				if _slots.has(n):
						_slots[n].append(null)
				else:
						_slots[n] = [null]

func get_item(slot: String, index: int = 0) -> Item:
				var arr: Array = _slots.get(slot, [])
				if index >= 0 and index < arr.size():
						return arr[index]
				return null

func get_all_items() -> Array:
				## Returns an array of all items currently equipped across all
				## slots. The array may contain `null` for empty slots. Useful for
				## systems that need to query every equipped item, such as hiding
				## the player's hair when a helmet is worn.
				var result: Array = []
				for arr in _slots.values():
						result.append_array(arr)
				return result

func equip(item: Item, index: int = -1) -> Item:
		# Equips the given item and returns any item that was previously in the
		# slot. When `index` is -1 the first free slot of the matching type is
		# used.
		if not item or item.equip_slot == "":
				return null
		var slot := item.equip_slot
		var arr: Array = _slots.get(slot, [])
		if arr.is_empty():
				return null
		var slot_index := index
		if slot_index < 0 or slot_index >= arr.size():
				slot_index = arr.find(null)
				if slot_index == -1:
						slot_index = 0
		var previous: Item = arr[slot_index]
		if previous:
				_remove_item(previous)
		arr[slot_index] = item
		_apply_item(item)
		emit_signal("slot_changed", slot, slot_index, item)
		return previous

func unequip(slot: String, index: int = 0) -> Item:
		# Removes the item from the slot and returns it.
		var arr: Array = _slots.get(slot, [])
		if index < 0 or index >= arr.size():
				return null
		var item: Item = arr[index]
		if item:
				_remove_item(item)
				arr[index] = null
				emit_signal("slot_changed", slot, index, null)
		return item

# -- Internal helpers -------------------------------------------------------

func _apply_item(item: Item) -> void:
		for affix in item.affixes:
				stats.apply_affix(affix)
		if item is Equipment:
				stats.base_evasion += item.base_evasion
				stats.base_block += item.base_block
				stats.base_damage_reduction += item.base_damage_reduction
				stats.base_max_energy_shield += item.base_energy_shield

func _remove_item(item: Item) -> void:
		for affix in item.affixes:
				stats.remove_affix(affix)
		if item is Equipment:
				stats.base_evasion -= item.base_evasion
				stats.base_block -= item.base_block
				stats.base_damage_reduction -= item.base_damage_reduction
				stats.base_max_energy_shield -= item.base_energy_shield
