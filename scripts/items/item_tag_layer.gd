class_name ItemTagLayer
extends CanvasLayer

## Central manager for item nameplates displayed above dropped items.
##
## Tags no longer attempt to resolve overlaps against their siblings every
## frame. Instead the layer clusters tags by the world position of their target
## and nearby neighbours, assigning each a stack index. `ItemTag` uses this
## index to apply vertical offsets in screen space and can spread very tall
## stacks into horizontal columns. Because items are static the stack only
## needs to be recalculated when tags are added or removed.

@export var vertical_spacing: float = 4.0
@export var horizontal_spacing: float = 8.0
@export var merge_distance: float = 1.5
@export var tag_styles: Array[ItemTagStyle] = []

# Array of dictionaries: {position: Vector3, tags: Array[ItemTag]}
var _groups: Array = []

## Register a tag with the layer so it becomes part of the stacking group.
## This function is also used when an offscreen pickup becomes visible again
## and needs to rejoin its group.
func add_tag(tag: ItemTag) -> void:
	show_tag(tag)

## Permanently remove a tag from the layer and free it.
func remove_tag(tag: ItemTag) -> void:
	hide_tag(tag)
	tag.queue_free()

## Temporarily hide a tag.  The tag stops processing and is removed from its
## stacking group but remains in memory so it can be shown again later.
func hide_tag(tag: ItemTag) -> void:
	if not is_instance_valid(tag):
		return
	_unregister_tag(tag)
	tag.visible = false
	tag.set_process(false)

## Restore a previously hidden tag.  The tag is added back to the layer and the
## stacking group is recalculated.
func show_tag(tag: ItemTag) -> void:
	if not is_instance_valid(tag):
		return
	if tag.get_parent() != self:
		add_child(tag)
	tag.visible = true
	tag.set_process(true)
	# Defer registration so the tag's size is valid before stacking.
	call_deferred("_register_tag", tag)

## Apply per-item styling such as colour and optional icon.
func apply_style(tag: ItemTag) -> void:
	if not tag.item:
		return
	var style := _get_style(tag.item.item_type)
	if style:
		tag.add_theme_color_override("font_color", style.color)
		if style.icon:
			tag.icon = style.icon

# --- Internal helpers -------------------------------------------------------

func _get_style(item_type: String) -> ItemTagStyle:
	for style in tag_styles:
		if style.item_type == item_type:
			return style
	return null

func _register_tag(tag: ItemTag) -> void:
	var pos: Vector3 = tag.target.global_transform.origin
	var merged_tags: Array = [tag]
	var merged_pos: Vector3 = pos
	var to_remove: Array = []
	for group in _groups:
		if group.position.distance_to(pos) <= merge_distance:
			merged_tags.append_array(group.tags)
			merged_pos = (merged_pos + group.position) * 0.5
			to_remove.append(group)
	for g in to_remove:
		_groups.erase(g)
	var new_group := {"position": merged_pos, "tags": merged_tags}
	_groups.append(new_group)
	_restack_group(new_group)

func _unregister_tag(tag: ItemTag) -> void:
	for group in _groups:
		if group.tags.has(tag):
			group.tags.erase(tag)
			if group.tags.is_empty():
				_groups.erase(group)
			else:
				group.position = _average_position(group.tags)
				_restack_group(group)
			return

func _restack_group(group: Dictionary) -> void:
	var tags: Array = group.tags
	tags = tags.filter(func(t):
		return is_instance_valid(t) and is_instance_valid(t.target))
	group.tags = tags
	if tags.is_empty():
		_groups.erase(group)
		return
	var max_w := 0.0
	var max_h := 0.0
	for t in tags:
		max_w = max(max_w, t.size.x)
		max_h = max(max_h, t.size.y)
	if max_w <= 0.0:
		max_w = 64.0
	if max_h <= 0.0:
		max_h = 16.0
	var viewport_height := get_viewport().size.y
	var row_height := max_h + vertical_spacing
	var rows_per_col := max(1, int(floor(viewport_height / row_height)))
	var columns := 1
	if tags.size() > rows_per_col:
		columns = min(3, int(ceil(float(tags.size()) / rows_per_col)))
	for i in range(tags.size()):
		var row := i % rows_per_col
		var col := i / rows_per_col
		var tag: ItemTag = tags[i]
		tag.set_stack_coords(row, col, columns, max_w, max_h, vertical_spacing, horizontal_spacing)

func _average_position(tags: Array) -> Vector3:
	var sum := Vector3.ZERO
	for t in tags:
		if is_instance_valid(t) and is_instance_valid(t.target):
			sum += t.target.global_transform.origin
	return sum / max(tags.size(), 1)
