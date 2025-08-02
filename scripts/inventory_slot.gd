extends Control
class_name InventorySlot

signal pressed(index: int)
signal right_clicked(index: int)

# If true, this slot represents an equipment slot rather than a standard
# inventory slot.  Equipment slots use `slot_type` to determine which items may
# be placed in them (e.g. "weapon" or "armor").
@export var is_equipment: bool = false
@export var slot_type: String = ""

@export var index: int = -1
var item: Item = null
var amount: int = 0

@onready var icon := $Icon if has_node("Icon") else null
@onready var quantity_label := $Amount if has_node("Amount") else null

func _ready() -> void:
	update_display()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			emit_signal("pressed", index)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			emit_signal("right_clicked", index)

func set_item(value: Item) -> void:
	item = value
	update_display()

func set_amount(value: int) -> void:
	amount = value
	update_display()

func update_display() -> void:
	#print("updating display")
	if icon:
		#print("updating icon")
		icon.texture = item.icon if item else null
	if quantity_label:
		quantity_label.text = str(amount) if amount >= 1 else ""
