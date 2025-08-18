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

## Register a tag with the layer.  The tag will become a child of the layer and
## automatically receive a stack index.
func add_tag(tag: ItemTag) -> void:
        add_child(tag)
        _register_tag(tag)

## Remove a tag from the layer and update the remaining stack.
func remove_tag(tag: ItemTag) -> void:
        _unregister_tag(tag)
        tag.queue_free()

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
        for i in range(tags.size()):
                (tags[i] as ItemTag).set_stack_index(i, vertical_spacing)

## Generate a dictionary key based on an item's world position.  Rounding keeps
## nearby floating point values grouped together.
func _key_from_target(target: Node3D) -> Vector3i:
        if not target:
                return Vector3i.ZERO
        return Vector3i(target.global_transform.origin.round())
