extends CanvasLayer
class_name ItemTagLayer

@export var vertical_spacing: float = 4.0
@export var tag_styles: Array[ItemTagStyle] = []

var _needs_stack := false

func request_stack_update() -> void:
	if _needs_stack:
		return
	_needs_stack = true
	call_deferred("_update_stacks")

func _update_stacks() -> void:
	_needs_stack = false
	var groups: Dictionary = {}
	for child in get_children():
		if not child is ItemTag:
			continue
		var key := Vector2i(child.position.round())
		if not groups.has(key):
			groups[key] = []
		groups[key].append(child)
	for tags in groups.values():
		if tags.size() <= 1:
			continue
		for i in range(tags.size()):
			var tag: ItemTag = tags[i]
			tag.position.y -= i * (tag.size.y + vertical_spacing)

func apply_style(tag: ItemTag) -> void:
	if not tag.item:
		return
	var style := _get_style(tag.item.item_type)
	if style:
		tag.add_theme_color_override("font_color", style.color)
		if style.icon:
			tag.icon = style.icon

func _get_style(item_type: String) -> ItemTagStyle:
	for style in tag_styles:
		if style.item_type == item_type:
			return style
	return null
