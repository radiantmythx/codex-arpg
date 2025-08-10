extends Button
class_name ItemTag

var target: Node3D
@export var vertical_offset: float = 1.5
var _camera: Camera3D
var item: Item
var move_step = 0.5
# Additional offset applied when resolving overlap. This is recomputed every
# frame so the tag can react to movement of its target.
var _offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	_camera = get_viewport().get_camera_3d()
	focus_mode = FOCUS_NONE
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

func _process(delta: float) -> void:
	if not target or not is_instance_valid(target):
		queue_free()
		return
	if not _camera:
		_camera = get_viewport().get_camera_3d()
		if not _camera:
			return
		# Project the target's 3D position into 2D screen space.
		var pos := target.global_transform.origin
		pos.y += vertical_offset
		var screen_point: Vector2 = _camera.unproject_position(pos)

		# Base position of the tag before applying any overlap resolution.
		var base_pos := screen_point - size * 0.5
		position = base_pos

		# Item tags are always visible; camera culling is handled elsewhere.
		visible = true

		# Adjust position if this tag overlaps any siblings.
		resolve_overlap(base_pos)
			
## Resolve 2D rectangle collisions against other tags in the same layer.
## A small vertical offset is applied until no overlaps remain.
func resolve_overlap(base_pos: Vector2) -> void:
		var parent := get_parent()
		if not parent:
				return

		var siblings = parent.get_children()
		var moved := true
		var iterations := 0
		_offset = Vector2.ZERO
		var my_rect := Rect2(base_pos, size)

		# Keep trying to move until no collisions remain or a safety cap is hit.
		while moved and iterations < 16:
				moved = false
				for other in siblings:
						if other == self:
								continue
						var other_rect = Rect2(other.position, other.size)
						if my_rect.intersects(other_rect):
								var overlap = (my_rect.position.y + my_rect.size.y) - other_rect.position.y
								_offset.y -= overlap + move_step
								my_rect.position.y -= overlap + move_step
								moved = true
								break # restart loop after adjusting
				iterations += 1

		position = base_pos + _offset
