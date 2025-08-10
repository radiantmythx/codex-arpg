extends Button
class_name ItemTag

var target: Node3D
@export var vertical_offset: float = 1.5
var _camera: Camera3D
var item: Item
var move_step = 0.5

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
	var pos := target.global_transform.origin
	pos.y += vertical_offset
	var screen_point: Vector2 = _camera.unproject_position(pos)
	position = screen_point - size * 0.5
	#visible = _camera.is_position_behind(pos) == false
	visible = true
	var layer := get_parent()
	if layer and layer.has_method("request_stack_update"):
			layer.request_stack_update()
	await get_tree().process_frame
	resolve_overlap()
			
func resolve_overlap():
	var siblings = get_parent().get_children()
	var moved = true
	
	# Keep trying to move until no collisions remain
	while moved:
		moved = false
		for other in siblings:
			if other == self:
				continue
			if _is_colliding_with(other):
				position.y -= move_step
				moved = true
				break # Check again from start after moving

func _is_colliding_with(other: Control) -> bool:
	# Check rectangle overlap in global space
	var rect1 = get_global_rect()
	var rect2 = other.get_global_rect()
	return rect1.intersects(rect2)
