extends VisibleOnScreenNotifier3D
## Offscreen culler that keeps working even when visuals are hidden.
class_name OffscreenCuller

@export var target_path: NodePath = ^".."
## Optional node to hide when culled. If empty, nothing is hidden (processing still toggles).
@export var visual_path: NodePath
## If true, derive this notifier's AABB from the first VisualInstance3D under target.
@export var auto_aabb_from_visual: bool = true
## Manual AABB (used if auto_aabb_from_visual = false or no visual found).
@export var manual_aabb_size: Vector3 = Vector3(2, 2, 2) # centered on this node

var _target: Node3D
var _visual: Node3D

func _ready() -> void:
	_target = get_node_or_null(target_path)
	if visual_path != NodePath():
		_visual = get_node_or_null(visual_path)
	if not _visual and _target:
		# Only use the target as "visual" if you know it's safe to hide it.
		# Otherwise, leave _visual empty and just toggle processing.
		_visual = null

	# Give the notifier its own AABB so it keeps detecting even if visuals are hidden.
	_set_notifier_aabb()

	connect("screen_exited", Callable(self, "_on_screen_exited"))
	connect("screen_entered", Callable(self, "_on_screen_entered"))

	# Sync initial state on next idle to avoid the first-frame gap.
	call_deferred("_sync_initial_state")


func _set_notifier_aabb() -> void:
	if auto_aabb_from_visual and _target:
		var vi := _find_first_visual_instance(_target)
		if vi:
			# Use the visual's local AABB but assign it to THIS notifier (in its local space).
			# Place the notifier at/under the target so transforms line up in practice.
			self.aabb = vi.get_aabb()
			return
	# Fallback: a simple box centered on this node.
	self.aabb = AABB(-manual_aabb_size * 0.5, manual_aabb_size)


func _find_first_visual_instance(root: Node) -> VisualInstance3D:
	if root is VisualInstance3D:
		return root
	for c in root.get_children():
		var vi := _find_first_visual_instance(c)
		if vi:
			return vi
	return null


func _sync_initial_state() -> void:
	_set_active(is_on_screen())


func _on_screen_exited() -> void:
	_set_active(false)


func _on_screen_entered() -> void:
	_set_active(true)


func _set_active(active: bool) -> void:
	# Toggle rendering on the optional visual only (not the one that provides the notifier's AABB).
	if _visual:
		_visual.visible = active

	if not _target:
		return

	# Toggle processing for the target (keep this culler running).
	if _target != self:
		_target.set_process(active)
		_target.set_physics_process(active)
		_target.set_process_input(active)
		_target.set_process_unhandled_input(active)
		_target.set_process_unhandled_key_input(active)

	# Children: skip the culler itself.
	for child in _target.get_children():
		if child == self:
			continue
		# Scripted processing
		child.set_process(active) if "set_process" in child else null
		child.set_physics_process(active) if "set_physics_process" in child else null
		child.set_process_input(active) if "set_process_input" in child else null
		child.set_process_unhandled_input(active) if "set_process_unhandled_input" in child else null
		child.set_process_unhandled_key_input(active) if "set_process_unhandled_key_input" in child else null

		# Common heavy nodes
		if child is AnimationPlayer:
			if active:
				# leave it paused until something plays it intentionally
				child.playback_active = true
			else:
				child.playback_active = false
		elif child is GPUParticles3D:
			child.emitting = active
		elif child is CPUParticles3D:
			child.emitting = active
		elif child is Timer:
			child.paused = not active

	# Freeze CharacterBody3D motion when culled.
	if not active and _target is CharacterBody3D:
		var body := _target as CharacterBody3D
		body.velocity = Vector3.ZERO
