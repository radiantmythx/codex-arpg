class_name SkillSlot
extends TextureButton

signal right_clicked(index: int)

@export var index: int = -1
var skill: Skill = null

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			emit_signal("pressed", index)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			emit_signal("right_clicked", index)

func set_skill(value: Skill) -> void:
	skill = value
	texture_normal = skill.icon if skill else null
	tooltip_text = skill.name if skill else ""
