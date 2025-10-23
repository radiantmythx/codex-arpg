class_name BuffManager
extends Node

var stats: Stats
var _active: Array = []   # each item: { buff, affix, time, fx, overlay_copy, meshes }
var _entity

const FX_ANCHOR_NAME := "__BuffFX"  # all buff fx will be parented under this child node

func _ready() -> void:
	set_physics_process(true)
	_entity = get_parent()
	_ensure_fx_anchor()

func _physics_process(delta: float) -> void:
	for i in range(_active.size() - 1, -1, -1):
		var data = _active[i]
		if data.time > 0.0:
			data.time -= delta

			# Example tick for DoTs (keep your existing logic)
			if data.buff is DamageOverTimeBuff and _entity and _entity.has_method("take_damage"):
				var dot: DamageOverTimeBuff = data.buff
				_entity.take_damage(randf_range(dot.base_damage_low, dot.base_damage_high) * delta, dot.damage_type)

			if data.time <= 0.0:
				# on expire: remove stats + visuals
				stats.remove_affix(data.affix)
				_remove_visuals_for_entry(data)
				_active.remove_at(i)

func apply_buff(buff: Buff) -> void:
	if not stats:
		return

	var affix = buff._create_affix()
	stats.apply_affix(affix)

	# Prepare a record for this particular application (so we can fully undo it later).
	var entry := {
		"buff": buff,
		"affix": affix,
		"time": buff.duration,
		"fx": null,               # Node instance (if any)
		"overlay_copy": null,     # unique duplicated Material we push into overlay chain
		"meshes": []              # list of MeshInstance3D we touched (for fast cleanup)
	}

	# 1) Spawn/attach FX scene (if set)
	if buff.fx_scene and is_instance_valid(_entity):
		entry.fx = _spawn_fx_for_buff(buff)

	# 2) Apply overlay material (stack-safe)
	if buff.overlay_material and is_instance_valid(_entity):
		entry.overlay_copy = buff.overlay_material.duplicate() # unique per application, so we can identify it later
		entry.meshes = _apply_overlay_material(entry.overlay_copy)

	_active.append(entry)

func remove_buff(buff: Buff) -> void:
	# Remove ALL active instances that came from this exact Resource (safe if you allow stacking)
	for i in range(_active.size() - 1, -1, -1):
		var data = _active[i]
		if data.buff == buff:
			stats.remove_affix(data.affix)
			_remove_visuals_for_entry(data)
			_active.remove_at(i)

# ------------------------
# Helpers
# ------------------------

func _ensure_fx_anchor() -> void:
	if not is_instance_valid(_entity):
		return
	if not _entity.has_node(FX_ANCHOR_NAME):
		var anchor := Node3D.new()
		anchor.name = FX_ANCHOR_NAME
		_entity.add_child(anchor)
		anchor.top_level = false  # stays relative to entity
		anchor.owner = _entity.get_owner()

func _get_fx_anchor() -> Node3D:
	if is_instance_valid(_entity) and _entity.has_node(FX_ANCHOR_NAME):
		return _entity.get_node(FX_ANCHOR_NAME) as Node3D
	return null

func _spawn_fx_for_buff(buff: Buff) -> Node:
	var fx_anchor := _get_fx_anchor()
	if fx_anchor == null:
		return null

	var fx_instance := buff.fx_scene.instantiate()
	# Attach either to a specific child path or to the anchor
	if buff.fx_attach_path != NodePath() and _entity.has_node(buff.fx_attach_path):
		var target = _entity.get_node(buff.fx_attach_path)
		target.add_child(fx_instance)
		if fx_instance is Node3D:
			(fx_instance as Node3D).position += buff.fx_local_offset
	else:
		fx_anchor.add_child(fx_instance)
		if fx_instance is Node3D:
			(fx_instance as Node3D).position = buff.fx_local_offset

	# Ensure it follows entity by hierarchy; no per-frame follow code needed.
	return fx_instance

func _apply_overlay_material(overlay_mat_copy: Material) -> Array:
	# Walk all MeshInstance3D under the entity and push our overlay on top of any existing chains.
	var touched_meshes: Array = []
	if not is_instance_valid(_entity):
		return touched_meshes

	for mesh in _entity.get_tree().get_nodes_in_group("__temp_find_meshes__"): # small optimization pattern below
		# no-op (placeholder)
		pass

	# Safer generic traversal (works without pre-grouping):
	var stack := [_entity]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for child in n.get_children():
			stack.append(child)
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			# Put our unique overlay at the TOP of the chain so removal is O(1) if it's still the head.
			overlay_mat_copy.next_pass = mi.material_overlay
			mi.material_overlay = overlay_mat_copy
			touched_meshes.append(mi)

	return touched_meshes

func _remove_visuals_for_entry(entry: Dictionary) -> void:
	# 1) Remove FX
	if entry.fx and is_instance_valid(entry.fx):
		entry.fx.queue_free()

	# 2) Pop our overlay out of each mesh's overlay chain
	var overlay_copy: Material = entry.overlay_copy
	if overlay_copy:
		for mi in entry.meshes:
			if not is_instance_valid(mi):
				continue
			mi.material_overlay = _unlink_overlay_chain(mi.material_overlay, overlay_copy)

# Unlink a specific Material from a next_pass chain. Returns the new chain head.
func _unlink_overlay_chain(root: Material, target: Material) -> Material:
	if root == null or target == null:
		return root
	# If the head is the target, pop it
	if root == target:
		return target.next_pass

	# Otherwise, find and skip it in the chain
	var parent := root
	var current := root.next_pass
	while current:
		if current == target:
			parent.next_pass = current.next_pass
			return root
		parent = current
		current = current.next_pass
	return root
