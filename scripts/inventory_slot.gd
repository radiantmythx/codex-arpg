extends Control
class_name InventorySlot

var item: Item = null
var amount: int = 0

@onready var icon := $Icon if has_node("Icon") else null
@onready var quantity_label := $Amount if has_node("Amount") else null

func _ready() -> void:
		update_display()

func set_item(value: Item) -> void:
		item = value
		update_display()

func set_amount(value: int) -> void:
		amount = value
		update_display()

func update_display() -> void:
		print("updating display")
		if icon:
				print("updating icon")
				icon.texture = item.icon if item else null
		if quantity_label:
				quantity_label.text = str(amount) if amount >= 1 else ""
