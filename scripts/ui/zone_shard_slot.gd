class_name ZoneShardSlot
extends Control

# UI control containing a single InventorySlot for inserting a ZoneShard and a
# button to generate a zone from it.

signal zone_generated(scene: PackedScene)

@export var inventory_ui_path: NodePath
@export var shard_slot_path: NodePath
@export var go_button_path: NodePath
@export var zone_generator: ZoneGenerator

var _inventory_ui: InventoryUI
var _slot: InventorySlot
var _go_button: Button

func _ready() -> void:
	_inventory_ui = get_node_or_null(inventory_ui_path)
	_slot = get_node(shard_slot_path)
	_go_button = get_node(go_button_path)
	_slot.pressed.connect(_on_slot_pressed)
	_go_button.pressed.connect(_on_go_pressed)
	_update_button()

func _on_slot_pressed(_index: int) -> void:
	if not _inventory_ui:
		return
	var cursor_item: Item = _inventory_ui.get_cursor_item()
	if cursor_item:
		if cursor_item is ZoneShard:
			var payload = _inventory_ui.take_cursor_item()
			_slot.set_item(payload["item"])
			_slot.set_amount(1)
		# ignore non ZoneShard items
	elif _slot.item:
		var item = _slot.item
		_slot.set_item(null)
		_slot.set_amount(0)
		_inventory_ui.pickup_to_cursor(item, 1)
	_update_button()

func _on_go_pressed() -> void:
	if _slot.item and zone_generator:
		var scene = zone_generator.generate_zone([_slot.item])
		emit_signal("zone_generated", scene)
		_slot.set_item(null)
		_slot.set_amount(0)
	_update_button()

func _update_button() -> void:
	if _go_button:
		_go_button.disabled = _slot.item == null
