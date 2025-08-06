class_name RuneSlot
extends Control

signal right_clicked(slot: RuneSlot)
signal pressed
@onready var icon := $Icon if has_node("Icon") else null
# Index of the skill slot this rune slot belongs to (0 = main, 1 = secondary)
@export var skill_slot_index: int = 0
# Index within the skill slot (0 or 1)
@export var rune_index: int = 0

var rune: Rune = null

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			emit_signal("pressed")
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			emit_signal("right_clicked", self)

func set_rune(value: Rune) -> void:
	rune = value
	icon.texture = rune.icon if rune else null
	tooltip_text = rune.item_name if rune else ""
