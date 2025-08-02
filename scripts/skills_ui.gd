class_name SkillsUI
extends CanvasLayer

@export var known_skills_parent_path: NodePath
@export var slots_parent_path: NodePath

var _player
var _known_slots: Array = []
var _slots: Array = []
var _open := false
var _cursor_skill: Skill = null
var _cursor_icon: TextureRect

func _ready() -> void:
	if slots_parent_path != NodePath():
		var parent = get_node(slots_parent_path)
		_slots = parent.get_children()
		for i in range(_slots.size()):
			var slot = _slots[i]
			if slot.has_signal("pressed"):
				slot.index = i
				slot.connect("pressed", Callable(self, "_on_slot_pressed").bind(i))
	_cursor_icon = TextureRect.new()
	_cursor_icon.visible = false
	_cursor_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cursor_icon)
	set_process(true)
	visible = false

func bind_player(p) -> void:
	_player = p
	_update_known_skills()
	_update_slots()

func _process(_delta: float) -> void:
	if _cursor_icon.visible:
		_cursor_icon.global_position = get_viewport().get_mouse_position()

func open() -> void:
	_open = true
	visible = true
	_update_known_skills()
	_update_slots()
	_update_cursor_visibility()

func close() -> void:
	_open = false
	visible = false
	_update_cursor_visibility()

func _update_known_skills() -> void:
	if not _player or known_skills_parent_path == NodePath():
		return
	var parent = get_node(known_skills_parent_path)
	for child in parent.get_children():
		child.queue_free()
	_known_slots.clear()
	for i in range(_player.known_skills.size()):
		var skill = _player.known_skills[i]
		var slot = SkillSlot.new()
		slot.index = i
		slot.set_skill(skill)
		slot.connect("pressed", Callable(self, "_on_known_skill_pressed").bind(slot))
		parent.add_child(slot)
		_known_slots.append(slot)

func _update_slots() -> void:
	if not _player:
		return
	for i in range(_slots.size()):
		var slot = _slots[i]
		if slot.has_method("set_skill"):
			slot.set_skill(_player.get_skill_slot(i))

func _on_known_skill_pressed(slot: SkillSlot) -> void:
	_cursor_skill = slot.skill
	_update_cursor()

func _on_slot_pressed(index: int) -> void:
	if not _player:
		return
	var existing = _player.get_skill_slot(index)
	if _cursor_skill:
		_player.set_skill_slot(index, _cursor_skill)
		_cursor_skill = existing
	else:
		_cursor_skill = existing
		_player.set_skill_slot(index, null)
	_update_slots()
	_update_cursor()

func _update_cursor() -> void:
	if _cursor_skill:
		_cursor_icon.texture = _cursor_skill.icon
	_update_cursor_visibility()

func _update_cursor_visibility() -> void:
	_cursor_icon.visible = _cursor_skill != null and _open
