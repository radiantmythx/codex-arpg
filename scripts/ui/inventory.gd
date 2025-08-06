extends Node
class_name Inventory

signal slot_changed(index: int, item: Item, amount: int)

var _slots: Array = []

func set_size(count: int) -> void:
	_slots.resize(count)
	for i in range(_slots.size()):
		if typeof(_slots[i]) != TYPE_DICTIONARY:
			_slots[i] = {"item": null, "amount": 0}
		else:
			if not _slots[i].has("item"):
				_slots[i]["item"] = null
			if not _slots[i].has("amount"):
				_slots[i]["amount"] = 0
		emit_signal("slot_changed", i, _slots[i]["item"], _slots[i]["amount"])

func get_size() -> int:
	return _slots.size()

func get_slot(index: int) -> Dictionary:
	if index >= 0 and index < _slots.size():
		return _slots[index]
	return {"item": null, "amount": 0}

func take_from_slot(index: int) -> Dictionary:
	var slot := get_slot(index)
	clear_slot(index)
	return slot

func clear_slot(index: int) -> void:
	if index >= 0 and index < _slots.size():
		_slots[index] = {"item": null, "amount": 0}
		emit_signal("slot_changed", index, null, 0)

func place_item(index: int, item: Item, amount: int) -> Dictionary:
	#print("Starting place item logic")
	if index < 0 or index >= _slots.size():
		#print("index lerss than 0 or index greater than or equal to slot size")
		return {"item": item, "amount": amount}
	var slot = _slots[index]
	if slot["item"] == null:
		#print("slot item is null")
		var to_place = min(item.max_stack, amount)
		_slots[index] = {"item": item, "amount": to_place}
		emit_signal("slot_changed", index, item, to_place)
		if amount - to_place > 0:
			#print("amount - to place greater than 0")
			return {"item": item, "amount": amount - to_place}
		return Dictionary()
	elif slot["item"] == item and slot["amount"] < item.max_stack:
		#print("slot has item and is less than max stack")
		var to_add = min(item.max_stack - slot["amount"], amount)
		slot["amount"] += to_add
		_slots[index] = slot
		emit_signal("slot_changed", index, item, slot["amount"])
		if amount - to_add > 0:
			return {"item": item, "amount": amount - to_add}
		return Dictionary()
	else:
		#print("else statement in place item")
		_slots[index] = {"item": item, "amount": amount}
		emit_signal("slot_changed", index, item, amount)
		return slot

func add_item(item: Item, amount: int = 1) -> void:
	var remaining := amount
	for i in range(_slots.size()):
		var slot = _slots[i]
		if slot["item"] == item and slot["amount"] < item.max_stack:
			var to_add = min(item.max_stack - slot["amount"], remaining)
			slot["amount"] += to_add
			_slots[i] = slot
			emit_signal("slot_changed", i, slot["item"], slot["amount"])
			remaining -= to_add
			if remaining <= 0:
				return
	for i in range(_slots.size()):
		var slot = _slots[i]
		if slot["item"] == null:
			var to_add = min(item.max_stack, remaining)
			_slots[i] = {"item": item, "amount": to_add}
			emit_signal("slot_changed", i, item, to_add)
			remaining -= to_add
			if remaining <= 0:
				return

func has_item(item: Item, amount: int = 1) -> bool:
	var total := 0
	for slot in _slots:
		if slot["item"] == item:
			total += slot["amount"]
	return total >= amount

func get_items() -> Array:
	return _slots.duplicate()
