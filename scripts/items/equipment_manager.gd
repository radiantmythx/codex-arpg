extends Node
class_name EquipmentManager

# Handles equipping and unequipping of items and applies their affixes to a
# `Stats` instance.  The manager keeps track of items by slot name and emits a
# signal whenever a slot changes.

signal slot_changed(slot: String, item: Item)

@export var stats: Stats

# Dictionary of slot -> Item. Slots are created via `set_slots`.
var _slots: Dictionary = {}

func set_slots(names: Array) -> void:
	# Initializes the available equipment slots. Call once on setup.
	for n in names:
		_slots[n] = null

func get_item(slot: String) -> Item:
	return _slots.get(slot, null)

func equip(item: Item) -> Item:
	# Equips the given item and returns any item that was previously in the slot.
	if not item or item.equip_slot == "":
		return null
	var slot := item.equip_slot
	var previous: Item = _slots.get(slot, null)
	if previous:
		_remove_item(previous)
	_slots[slot] = item
	_apply_item(item)
	emit_signal("slot_changed", slot, item)
	return previous

func unequip(slot: String) -> Item:
	# Removes the item from the slot and returns it.
	var item: Item = _slots.get(slot, null)
	if item:
		_remove_item(item)
		_slots[slot] = null
		emit_signal("slot_changed", slot, null)
	return item

# -- Internal helpers -------------------------------------------------------

func _apply_item(item: Item) -> void:
	for affix in item.affixes:
		stats.apply_affix(affix)

func _remove_item(item: Item) -> void:
	for affix in item.affixes:
		stats.remove_affix(affix)
