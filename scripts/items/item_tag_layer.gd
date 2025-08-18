class_name ItemTagLayer
extends CanvasLayer

## Central manager for item nameplates displayed above dropped items.
##
## Tags no longer attempt to resolve overlaps against their siblings every
## frame.  Instead the layer groups tags by the world position of their target
## `ItemPickup` and assigns each tag a stack index.  This index is used by
## `ItemTag` to apply a fixed vertical offset in screen space, effectively
## creating a column of labels for items that occupy the same location.  Because
## items are static the stack only needs to be recalculated when tags are added
## or removed.

@export var vertical_spacing: float = 4.0
@export var tag_styles: Array[ItemTagStyle] = []

# Dictionary mapping a world-position key to an array of tags at that location.
var _groups: Dictionary = {}

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
                _register_tag(tag)

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
                var key := _key_from_target(tag.target)
                if not _groups.has(key):
                                _groups[key] = []
                _groups[key].append(tag)
                _restack_group(key)

func _unregister_tag(tag: ItemTag) -> void:
                var key := _key_from_target(tag.target)
                if not _groups.has(key):
                                return
                _groups[key].erase(tag)
                if _groups[key].is_empty():
                                _groups.erase(key)
                else:
                                _restack_group(key)

func _restack_group(key: Vector3i) -> void:
                var tags: Array = _groups.get(key, [])
                var i := 0
                while i < tags.size():
                                var tag: ItemTag = tags[i]
                                if not is_instance_valid(tag) or not is_instance_valid(tag.target):
                                                tags.remove_at(i)
                                                continue
                                tag.set_stack_index(i, vertical_spacing)
                                i += 1
                if tags.is_empty():
                                _groups.erase(key)

## Generate a dictionary key based on an item's world position.  Rounding keeps
## nearby floating point values grouped together.
func _key_from_target(target: Node3D) -> Vector3i:
                if not target or not is_instance_valid(target):
                                return Vector3i.ZERO
                return Vector3i(target.global_transform.origin.round())
