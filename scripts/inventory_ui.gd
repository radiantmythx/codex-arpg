extends CanvasLayer
class_name InventoryUI

@export var slots_parent_path: NodePath
@export var camera_path: NodePath
@export var camera_shift: float = 3.0

var _slots: Array = []
var _inventory: Inventory
var _camera: Camera3D
var _camera_base_pos: Vector3
var _open := false

var _cursor_item: Item = null
var _cursor_amount: int = 0
var _cursor_icon: TextureRect
var _cursor_label: Label

func _ready() -> void:
	if slots_parent_path != NodePath():
		var parent = get_node(slots_parent_path)
		_slots = parent.get_children()
		#print("set slots")
		for i in range(_slots.size()):
			var slot = _slots[i]
			if slot.has_method("set_item"):
				slot.index = i
				if slot.has_signal("pressed"):
					slot.connect("pressed", Callable(self, "_on_slot_pressed"))
	if camera_path != NodePath():
		_camera = get_node(camera_path)
		if _camera:
			_camera_base_pos = _camera.position
	_cursor_icon = TextureRect.new()
	_cursor_icon.visible = false
	_cursor_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cursor_icon)
	_cursor_label = Label.new()
	_cursor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_icon.add_child(_cursor_label)
	set_process(true)
	visible = false
	if(_inventory):
		bind_inventory(_inventory)

func _process(_delta: float) -> void:
	if _cursor_icon.visible:
		_cursor_icon.global_position = get_viewport().get_mouse_position()

func bind_inventory(inv: Inventory) -> void:
	_inventory = inv
	if _inventory:
		_inventory.set_size(_slots.size())
		_inventory.connect("slot_changed", Callable(self, "_on_slot_changed"))
		_update_slots()

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
	tween.tween_property(_camera, "position", target, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_slot_changed(index: int, item: Item, amount: int) -> void:
	if index < 0 or index >= _slots.size():
		return
	var slot = _slots[index]
	if slot.has_method("set_item"):
		slot.set_item(item)
	if slot.has_method("set_amount"):
		slot.set_amount(amount)

func _on_slot_pressed(index: int) -> void:
	if not _inventory:
		return
	if _cursor_item:
		#print("trying to place item")
		var leftover = _inventory.place_item(index, _cursor_item, _cursor_amount)
		#print("leftover", leftover)
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

func pickup_to_cursor(item: Item, amount: int) -> void:
	if _cursor_item:
		_inventory.add_item(_cursor_item, _cursor_amount)
	_cursor_item = item
	_cursor_amount = amount
	_update_cursor()

func _update_cursor() -> void:
	if _cursor_item:
		_cursor_icon.texture = _cursor_item.icon
		_cursor_label.text = str(_cursor_amount) if _cursor_amount > 1 else ""
	_update_cursor_visibility()

func _update_cursor_visibility() -> void:
	_cursor_icon.visible = _cursor_item != null and _open
