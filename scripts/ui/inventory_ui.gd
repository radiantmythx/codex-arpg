class_name InventoryUI
extends CanvasLayer

@export var slots_parent_path: NodePath
@export var equip_slots_parent_path: NodePath
@export var camera_path: NodePath
@export var camera_shift: float = 3.0
@export var rune_slots_parent_path: NodePath

var _slots: Array = []
var _equip_slots: Array = []
var _rune_slots: Array = []
var _inventory: Inventory
var _equipment: EquipmentManager
var _camera: Camera3D
var _camera_base_pos: Vector3
var _open := false

var _cursor_item: Item = null
var _cursor_amount: int = 0
var _cursor_icon: TextureRect
var _cursor_label: Label
var _rune_manager: RuneManager


func _ready() -> void:
	_collect_slots()
#	if camera_path != NodePath():
#		_camera = get_node(camera_path)
#		if _camera:
#			_camera_base_pos = _camera.position
	_cursor_icon = TextureRect.new()
	_cursor_icon.visible = false
	_cursor_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cursor_icon)
	_cursor_label = Label.new()
	_cursor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_icon.add_child(_cursor_label)
	set_process(true)
	visible = false
	if _inventory:
		bind_inventory(_inventory)
	if _equipment:
		bind_equipment(_equipment)
	if _rune_manager:
		bind_rune_manager(_rune_manager)


func _process(_delta: float) -> void:
	if _cursor_icon.visible:
		_cursor_icon.global_position = get_viewport().get_mouse_position()


func bind_inventory(inv: Inventory) -> void:
	_inventory = inv
	if _inventory:
		_inventory.set_size(_slots.size())
		_inventory.connect("slot_changed", Callable(self, "_on_slot_changed"))
		_update_slots()


func bind_equipment(eq: EquipmentManager) -> void:
	_equipment = eq
	if _equipment:
		_equipment.connect("slot_changed", Callable(self, "_on_equip_slot_changed"))
		_update_equip_slots()

func bind_rune_manager(rm: RuneManager) -> void:
	_rune_manager = rm
	if _rune_manager:
		_rune_manager.connect("slot_changed", Callable(self, "_on_rune_slot_changed"))
		_update_rune_slots()


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func open() -> void:
	_open = true
	visible = true
	_shift_camera(true)
	_update_slots()
	_update_equip_slots()
	_update_rune_slots()
	_update_cursor_visibility()


func close() -> void:
	_open = false
	visible = false
	_shift_camera(false)
	_update_cursor_visibility()


func _shift_camera(open: bool) -> void:
	if not _camera:
		return
	var target := _camera_base_pos
	if open:
		target.x += camera_shift
	var tween := create_tween()
	tween.tween_property(_camera, "position", target, 0.25).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)


func _on_slot_changed(index: int, item: Item, amount: int) -> void:
	if index < 0 or index >= _slots.size():
		return
	var slot = _slots[index]
	if slot.has_method("set_item"):
		slot.set_item(item)
	if slot.has_method("set_amount"):
		slot.set_amount(amount)


func _on_equip_slot_changed(_slot: String, _index: int, _item: Item) -> void:
		_update_equip_slots()

func _on_rune_slot_changed(_slot_index: int, _rune_index: int, _rune: Rune) -> void:
	_update_rune_slots()


func _on_slot_pressed(index: int) -> void:
	if not _inventory:
		return
	if _cursor_item:
		print("cursor item")
		var leftover = _inventory.place_item(index, _cursor_item, _cursor_amount)
		if leftover:
			_cursor_item = leftover["item"]
			_cursor_amount = leftover["amount"]
		else:
			_cursor_item = null
			_cursor_amount = 0
		_update_cursor()
	else:
		var data = _inventory.take_from_slot(index)
		if data["item"]:
			_cursor_item = data["item"]
			_cursor_amount = data["amount"]
		_update_cursor()


func _on_slot_right_clicked(index: int) -> void:
	print("right clicked index ", index)
	if not _inventory:
		return

	var data = _inventory.get_slot(index)
	var item: Item = data["item"]
	if _cursor_item and item:
			print("Cursor item is", _cursor_item.item_name)
			var success := false
			match _cursor_item.item_name:
					"Chaos Orb":
							success = item.reroll_affixes()
					"Temper Jewel":
							print("Trying to apply temper jewel")
							success = item.temper_random_affix()
					"Culling Jewel":
							success = item.remove_random_affix()
					"Elevating Jewel":
							success = item.add_random_affix()
					"Cleansing Jewel":
							success = item.clear_affixes()
					_:
							pass
			if _cursor_item.item_name in ["Chaos Orb", "Temper Jewel", "Culling Jewel", "Elevating Jewel", "Cleansing Jewel"]:
					
					if success:
							_cursor_amount -= 1
							if _cursor_amount <= 0:
									_cursor_item = null
									_cursor_amount = 0
							_inventory.clear_slot(index)
							_inventory.place_item(index, item, data["amount"])
							_update_slots()
					_update_cursor()
					return
	if not _equipment:
			return
	if item and item.equip_slot != "":
			_inventory.clear_slot(index)
			var swapped = _equipment.equip(item)
			if swapped:
				var leftover = _inventory.place_item(index, swapped, 1)
				if leftover:
					_inventory.add_item(leftover["item"], leftover["amount"])
					_update_slots()
					_update_equip_slots()
					_update_rune_slots()


func _on_equip_slot_pressed(_index: int, slot: InventorySlot) -> void:
		if not _equipment:
				return
		if _cursor_item:
				if _cursor_item.equip_slot == slot.slot_type:
						# Pass the slot index so duplicate slot types (e.g. rings)
						# equip correctly.
						var swapped = _equipment.equip(_cursor_item, slot.index)
						_cursor_item = null
						_cursor_amount = 0
						if swapped:
								_cursor_item = swapped
								_cursor_amount = 1
						_update_cursor()
						_update_equip_slots()
						_update_rune_slots()
		else:
				var item = _equipment.unequip(slot.slot_type, slot.index)
				if item:
						_cursor_item = item
						_cursor_amount = 1
				_update_cursor()
				_update_equip_slots()


func _on_equip_slot_right_clicked(_index: int, slot: InventorySlot) -> void:
		if not _equipment or not _inventory:
				return
		var item = _equipment.unequip(slot.slot_type, slot.index)
		if item:
				_inventory.add_item(item)
				_update_slots()
				_update_equip_slots()
				_update_rune_slots()

func _on_rune_slot_pressed(slot: RuneSlot) -> void:
	if not _rune_manager:
		return
	if _cursor_item and _cursor_item is Rune:
		var swapped = _rune_manager.equip_rune(slot.skill_slot_index, slot.rune_index, _cursor_item)
		_cursor_item = swapped
		_cursor_amount = 1 if swapped else 0
		if not swapped:
			_cursor_item = null
			_cursor_amount = 0
		_update_cursor()
		_update_rune_slots()
	elif not _cursor_item:
		var r = _rune_manager.unequip_rune(slot.skill_slot_index, slot.rune_index)
		if r:
			_cursor_item = r
			_cursor_amount = 1
			_update_cursor()
			_update_rune_slots()

func _on_rune_slot_right_clicked(slot: RuneSlot) -> void:
	if not _rune_manager or not _inventory:
		return
	var r = _rune_manager.unequip_rune(slot.skill_slot_index, slot.rune_index)
	if r:
		_inventory.add_item(r)
		_update_slots()
		_update_rune_slots()


func _update_slots() -> void:
	if not _inventory:
		return
	var count = min(_slots.size(), _inventory.get_size())
	for i in range(count):
		var data = _inventory.get_slot(i)
		var slot = _slots[i]
		if slot.has_method("set_item"):
			slot.set_item(data["item"])
		if slot.has_method("set_amount"):
			slot.set_amount(data["amount"])


func _update_equip_slots() -> void:
		if not _equipment:
				return
		for slot in _equip_slots:
				# Fetch item using slot index so duplicate slot types work.
				var item = _equipment.get_item(slot.slot_type, slot.index)
				if slot.has_method("set_item"):
						slot.set_item(item)
				if slot.has_method("set_amount"):
						slot.set_amount(1 if item else 0)

func _update_rune_slots() -> void:
	if not _rune_manager:
		return
	for rslot in _rune_slots:
		var rune = _rune_manager.get_rune(rslot.skill_slot_index, rslot.rune_index)
		if rslot.has_method("set_rune"):
			rslot.set_rune(rune)


func pickup_to_cursor(item: Item, amount: int) -> void:
	if _cursor_item:
		_inventory.add_item(_cursor_item, _cursor_amount)
	_cursor_item = item
	_cursor_amount = amount
	_update_cursor()

func get_cursor_item() -> Item:
		return _cursor_item

func take_cursor_item() -> Dictionary:
		var data = {"item": _cursor_item, "amount": _cursor_amount}
		_cursor_item = null
		_cursor_amount = 0
		_update_cursor()
		return data


func _update_cursor() -> void:
	if _cursor_item:
		_cursor_icon.texture = _cursor_item.icon
		_cursor_label.text = str(_cursor_amount) if _cursor_amount > 1 else ""
	else:
		_cursor_icon.texture = null
		_cursor_label.text = ""
	_update_cursor_visibility()


func _update_cursor_visibility() -> void:
	_cursor_icon.visible = _cursor_item != null and _open

func _collect_slots() -> void:
	_slots.clear()
	_equip_slots.clear()
	_rune_slots.clear()
	var inv_slots: Array = find_children("*", "InventorySlot", true)
	var inv_index := 0
	var equip_counts := {}
	for slot in inv_slots:
			if slot.is_equipment:
					# Automatically assign an index to equipment slots if one
					# isn't provided so multiple slots of the same type (like
					# rings) can be distinguished.
					if slot.index < 0:
							var count = equip_counts.get(slot.slot_type, 0)
							slot.index = count
							equip_counts[slot.slot_type] = count + 1
					_equip_slots.append(slot)
					if slot.has_signal("pressed"):
							slot.connect("pressed", Callable(self, "_on_equip_slot_pressed").bind(slot))
					if slot.has_signal("right_clicked"):
							slot.connect("right_clicked", Callable(self, "_on_equip_slot_right_clicked").bind(slot))
			else:
					slot.index = inv_index
					inv_index += 1
					_slots.append(slot)
					if slot.has_signal("pressed"):
							slot.connect("pressed", Callable(self, "_on_slot_pressed"))
					if slot.has_signal("right_clicked"):
							slot.connect("right_clicked", Callable(self, "_on_slot_right_clicked"))

	var rslots: Array = find_children("*", "RuneSlot", true)
	for rslot in rslots:
		_rune_slots.append(rslot)
		if rslot.has_signal("pressed"):
			rslot.connect("pressed", Callable(self, "_on_rune_slot_pressed").bind(rslot))
		if rslot.has_signal("right_clicked"):
			rslot.connect("right_clicked", Callable(self, "_on_rune_slot_right_clicked"))
