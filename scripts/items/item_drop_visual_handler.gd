extends Node3D

@export var item_to_spawn:Item
@export var item_quant:int
@onready var pickup_area: ItemPickup = $PickupArea
@onready var drop_mesh: MeshInstance3D = $MeshInstance3D

func _ready():
	pickup_area.set_new_item(item_to_spawn)
	pickup_area.amount = item_quant
	await get_tree().physics_frame
	_apply_item_model_mesh()
	#await get_tree().physics_frame
	#slide_down_to_ground(drop_mesh)

func _apply_item_model_mesh() -> void:
	var model_res = pickup_area.item.model
	if model_res == null:
		print("no model")
		return

	# Case 1: model is already a Mesh resource
	if model_res is Mesh:
		print("Model is a mesh")
		drop_mesh.mesh = model_res
		return

	# Case 2: model is a PackedScene (common)
	if model_res is PackedScene:
		print("Model is a packed scene")
		var inst := (model_res as PackedScene).instantiate()
		# Try root first…
		var src := inst as MeshInstance3D
		# …or search descendants if needed
		if src == null:
			src = _find_first_mesh(inst)

		if src == null or src.mesh == null:
			push_warning("Model scene has no MeshInstance3D with a mesh.")
			inst.queue_free()
			return

		# Assign the mesh
		print("Assigning mesh to drop")
		drop_mesh.mesh = src.mesh
		drop_mesh.transform = src.transform

		# Optional: copy per-surface material overrides from the source instance
		if drop_mesh.mesh:
			var surf_count := drop_mesh.mesh.get_surface_count()
			for i in range(surf_count):
				var mat := src.get_surface_override_material(i)
				if mat:
					drop_mesh.set_surface_override_material(i, mat)
		drop_mesh.position.y += 0.1
		inst.queue_free()
		return
	push_warning("Unsupported model resource type: %s" % typeof(model_res))

func _find_first_mesh(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root
	for c in root.get_children():
		var found := _find_first_mesh(c)
		if found:
			return found
	return null

func slide_down_to_ground(
	node: Node3D,
	collision_mask: int = 1,
	duration: float = 0.25,
	gravity_dir: Vector3 = Vector3.DOWN,
	max_distance: float = 100.0,
	clearance: float = 0.01
) -> void:
	await get_tree().process_frame  # let transforms settle (useful right after warps)

	var vis := node as VisualInstance3D
	if vis == null:
		push_warning("slide_down_to_ground expects a VisualInstance3D (MeshInstance3D).")
		return

	var space := node.get_world_3d().direct_space_state
	var gt := node.global_transform
	var aabb := vis.get_aabb()

	# Sample the four bottom corners + center of the mesh in WORLD space
	var bottom_y := aabb.position.y
	var local_samples := [
		Vector3(aabb.position.x,                  bottom_y, aabb.position.z),
		Vector3(aabb.position.x + aabb.size.x,    bottom_y, aabb.position.z),
		Vector3(aabb.position.x,                  bottom_y, aabb.position.z + aabb.size.z),
		Vector3(aabb.position.x + aabb.size.x,    bottom_y, aabb.position.z + aabb.size.z),
		Vector3(aabb.get_center().x,              bottom_y, aabb.get_center().z),
	]

	var g := gravity_dir.normalized()
	var up := -g
	var start_points: Array[Vector3] = []
	for lp in local_samples:
		var wp = gt * lp
		start_points.append(wp + up * 0.05) # start slightly "above" to avoid starting inside

	# Find the *highest* ground hit beneath our samples (to avoid clipping on uneven ground)
	var highest_proj := -INF
	var hit_any := false
	for s in start_points:
		var to := s + g * max_distance
		var p := PhysicsRayQueryParameters3D.new()
		p.from = s
		p.to = to
		p.collision_mask = collision_mask
		p.exclude = [node]  # don't hit ourselves
		var res := space.intersect_ray(p)
		if res:
			hit_any = true
			var hit_pos: Vector3 = res.position
			highest_proj = max(highest_proj, hit_pos.dot(g))
	if not hit_any:
		return  # nothing below; do nothing

	# Current *lowest* projection among the same samples (how far "down" our bottom is)
	var lowest_proj := INF
	for lp in local_samples:
		var wp = gt * lp
		lowest_proj = min(lowest_proj, wp.dot(g))

	# Distance needed along gravity so our lowest point meets the highest ground point
	var needed := (highest_proj + clearance) - lowest_proj
	if needed <= 0.0:
		return  # already touching or below

	var start := node.global_position
	var end := start + g * needed

	if duration <= 0.0:
		node.global_position = end
	else:
		var tw := node.create_tween()
		tw.tween_property(node, "global_position", end, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await tw.finished
