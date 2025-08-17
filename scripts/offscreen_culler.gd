extends VisibleOnScreenNotifier3D
## Component that disables processing and rendering of a target node when it
## leaves the camera's view.  Attach as a child of the object to monitor.  This
## helps keep performance stable with large numbers of enemies.
##
## Godot 4.4 docs: https://docs.godotengine.org/en/latest/classes/class_visibleonscreennotifier3d.html
class_name OffscreenCuller

@export var target_path: NodePath = NodePath("..")
## Optional node to hide when culled. If left empty the target itself is hidden.
@export var visual_path: NodePath

var _target: Node3D
var _visual: Node3D

func _ready() -> void:
        _target = get_node_or_null(target_path)
        if visual_path != NodePath():
                _visual = get_node_or_null(visual_path)
        if not _visual and _target:
                _visual = _target
        connect("screen_exited", Callable(self, "_on_screen_exited"))
        connect("screen_entered", Callable(self, "_on_screen_entered"))

func _on_screen_exited() -> void:
        _set_active(false)

func _on_screen_entered() -> void:
        _set_active(true)

func _set_active(active: bool) -> void:
        # Toggle rendering.
        if _visual:
                _visual.visible = active
        if not _target:
                return
        # Toggle processing on the target while leaving this culler running.
        _target.set_process(active)
        _target.set_physics_process(active)
        for child in _target.get_children():
                if child == self:
                        continue
                child.set_process(active)
                child.set_physics_process(active)
        if not active and _target is CharacterBody3D:
                _target.velocity = Vector3.ZERO
