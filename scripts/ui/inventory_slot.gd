class_name InventorySlot
extends Control

signal pressed(index: int)
signal right_clicked(index: int)

# If true, this slot represents an equipment slot rather than a standard
# inventory slot.  Equipment slots use `slot_type` to determine which items may
# be placed in them (e.g. "weapon" or "armor").
@export var is_equipment: bool = false
@export var slot_type: String = ""

# Index distinguishes multiple equipment slots of the same type (e.g. ring 0
# and ring 1). InventoryUI will auto-assign if left at the default value.
@export var index: int = -1
var item: Item = null
var amount: int = 0

@onready var icon := $Icon if has_node("Icon") else null
@onready var quantity_label := $Amount if has_node("Amount") else null
@onready var requirement_overlay := $RequirementOverlay if has_node("RequirementOverlay") else null

var _stats: Stats


func _ready() -> void:
	update_display()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			print("I have been clicked! I am index ", index, " and slot type ", slot_type)
			emit_signal("pressed", index)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			emit_signal("right_clicked", index)


func set_item(value: Item) -> void:
	item = value
	update_display()


func set_amount(value: int) -> void:
		amount = value
		update_display()


func set_stats(s: Stats) -> void:
		_stats = s
		update_display()


func update_display() -> void:
		#print("updating display")
		if icon:
				icon.texture = item.icon if item else null
		if quantity_label:
				quantity_label.text = str(amount) if amount > 1 else ""
		if item:
				tooltip_text = item.get_display_text()
		else:
				tooltip_text = ""
		if requirement_overlay:
				requirement_overlay.visible = item and _stats and not item.requirements_met(_stats)
