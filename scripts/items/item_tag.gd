class_name ItemTag
extends Button

## Node in charge of displaying a pickup's name above the item.
##
## Historically each tag tried to resolve overlaps with every other tag every
## frame.  That resulted in an \(N^2\) cost as the number of dropped items
## increased.  The new system stores a "stack index" computed by
## `ItemTagLayer` when a tag is created or removed.  During `_process` we simply
## project the target into screen space and apply the precomputed offset.  This
## keeps the tags in a stable vertical stack while only performing the expensive
## grouping logic when absolutely necessary.

@export var vertical_offset: float = 1.5
var item: Item
var target: Node3D
var _camera: Camera3D

# Index within a stack of tags that occupy the same world position.
var _stack_index: int = 0
# Cached spacing between stacked tags provided by the layer.
var _stack_spacing: float = 0.0

func _ready() -> void:
		_camera = get_viewport().get_camera_3d()
		focus_mode = FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_STOP
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		clip_text = false

func set_item(it: Item) -> void:
		item = it
		text = it.item_name
		var tip := "%s\n%s" % [it.item_name, it.description]
		var aff_text := it.get_affix_text()
		if aff_text != "":
				tip += "\n" + aff_text
		tooltip_text = tip
		_apply_style()

func _apply_style() -> void:
				var layer := get_parent()
				if layer and layer.has_method("apply_style"):
								layer.apply_style(self)

## Called by `ItemTagLayer` whenever the tag's stack position changes.
func set_stack_index(idx: int, spacing: float) -> void:
		_stack_index = idx
		_stack_spacing = spacing

func _process(_delta: float) -> void:
                if not target or not is_instance_valid(target):
                                queue_free()
                                return
                var current_camera := get_viewport().get_camera_3d()
                if not _camera or not is_instance_valid(_camera) or _camera != current_camera:
                                _camera = current_camera
                                if not _camera:
                                                return

		# Project the target's 3D position into 2D screen space.
		var pos := target.global_transform.origin
		pos.y += vertical_offset
		var screen_point: Vector2 = _camera.unproject_position(pos)

		# Base position of the tag before applying the stack offset.
		var base_pos := screen_point - size * 0.5

		# Apply the vertical stack offset.  The layer provides the spacing in
		# pixels so tags from the same world position form a readable column.
		base_pos.y -= _stack_index * (size.y + _stack_spacing)
		position = base_pos

		# Tags are always visible; camera culling is handled elsewhere.
		visible = true
