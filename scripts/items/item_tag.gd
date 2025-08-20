class_name ItemTag
extends Button

## Node in charge of displaying a pickup's name above the item.
##
## Historically each tag tried to resolve overlaps with every other tag every
## frame.  That resulted in an (N^2) cost as the number of dropped items
## increased.  The new system stores a stack position computed by
## `ItemTagLayer` when a tag is created or removed.  During `_process` we simply
## project the target into screen space and apply the precomputed offsets.  This
## keeps the tags in a stable stack while only performing the expensive grouping
## logic when absolutely necessary.

@export var vertical_offset: float = 1.5
var item: Item
var target: Node3D
var _camera: Camera3D

# Position within a stack of tags calculated by the layer.
var _stack_row: int = 0
var _stack_col: int = 0
var _stack_columns: int = 1
var _stack_width: float = 0.0
var _stack_height: float = 0.0
var _v_spacing: float = 0.0
var _h_spacing: float = 0.0

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
        tooltip_text = it.get_display_text()
        _apply_style()

func _apply_style() -> void:
	var layer := get_parent()
	if layer and layer.has_method("apply_style"):
		layer.apply_style(self)

## Called by `ItemTagLayer` whenever the tag's stack position changes.
func set_stack_coords(row: int, col: int, columns: int, width: float, height: float, v_spacing: float, h_spacing: float) -> void:
	_stack_row = row
	_stack_col = col
	_stack_columns = columns
	_stack_width = width
	_stack_height = height
	_v_spacing = v_spacing
	_h_spacing = h_spacing

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

	# Base position of the tag before applying stack offsets.
	var base_pos := screen_point - size * 0.5

	# Apply vertical stack offset and center within row height.
	base_pos.y -= _stack_row * (_stack_height + _v_spacing)
	base_pos.y -= (_stack_height - size.y) * 0.5

	# Apply horizontal offset. Center the whole group on the target.
	var total_width := _stack_columns * _stack_width + (_stack_columns - 1) * _h_spacing
	base_pos.x -= total_width * 0.5
	base_pos.x += _stack_col * (_stack_width + _h_spacing)
	base_pos.x += (_stack_width - size.x) * 0.5

	position = base_pos

	# Tags are always visible; camera culling is handled elsewhere.
	visible = true
