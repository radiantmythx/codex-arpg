extends Button
class_name ItemTag

var target: Node3D
@export var vertical_offset: float = 1.5
var _camera: Camera3D

func _ready() -> void:
    _camera = get_viewport().get_camera_3d()
    focus_mode = FOCUS_NONE
    size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    size_flags_vertical = Control.SIZE_SHRINK_CENTER
    clip_text = false

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
    visible = _camera.is_position_behind(pos) == false
