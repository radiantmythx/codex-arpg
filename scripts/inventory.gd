extends Node
class_name Inventory

signal item_added(item: Item)
signal item_removed(item: Item)

var _items: Dictionary = {}

func add_item(item: Item, amount: int = 1) -> void:
	var count: int = _items.get(item, 0) + amount
	_items[item] = min(count, item.max_stack)
	emit_signal("item_added", item)

func remove_item(item: Item, amount: int = 1) -> void:
	if not _items.has(item):
		return
	var count: int = _items[item] - amount
	if count <= 0:
		_items.erase(item)
	else:
		_items[item] = count
	emit_signal("item_removed", item)

func get_quantity(item: Item) -> int:
	return _items.get(item, 0)

func has_item(item: Item, amount: int = 1) -> bool:
	return get_quantity(item) >= amount

func get_items() -> Dictionary:
	return _items.duplicate()
