extends Node3D
class_name EquipmentVisualManager

##
# Handles instancing and attachment of 3D models for equipped items.
#
# This node listens to an [EquipmentManager] and spawns the `Item.model`
# scenes when items are equipped.  Models are attached to the player's
# skeleton so they follow animations.  Weapon and offhand items are attached
# to specific hand bones via [BoneAttachment3D] nodes while armour meshes are
# skinned to the skeleton directly.
#
# Usage:
#   1. Create this node and assign the `skeleton` and `equipment` properties.
#   2. The manager will automatically respond to `slot_changed` signals.
#   3. Ensure `Item.equip_transform` is configured so the model aligns
#      correctly with the player's hand or body.
##

@export var skeleton: Skeleton3D ## Player skeleton used for attachments.
@export var equipment: EquipmentManager ## Source of equip/unequip events.
# Optional hair scene that is attached to the head and hidden when certain
# items (e.g. helmets) request it.  The scene should be authored in the
# player's local space with the origin at the head bone.
@export var hair_scene: PackedScene

## Mapping of equipment slot names to the skeleton bone used for attachment.
## Slots not listed here will be added directly under the skeleton.
const SLOT_BONES := {
	"weapon": "mixamorig_RightHand",
	"offhand": "mixamorig_LeftHand",
}

# Instanced models currently attached, indexed by slot.
var _models: Dictionary = {}

# BoneAttachment3D nodes created for hand slots.
var _attachments: Dictionary = {}

# Instanced hair model if `hair_scene` is provided.
var _hair_instance: Node3D

func _ready() -> void:
	if equipment:
		equipment.connect("slot_changed", _on_slot_changed)
	# Pre-create attachment points for mapped slots.
	if skeleton:
		for slot in SLOT_BONES.keys():
			var bone_find := skeleton.find_bone(SLOT_BONES[slot])
				#if bone_find == -1:
					#print("COULD NOT FIND SKELETON")
			var bone_name: String = SLOT_BONES[slot]
			var attach := BoneAttachment3D.new()
			attach.bone_name = bone_name
			skeleton.add_child(attach)
				#print("Set up attach slot for slot: ", slot)
			_attachments[slot] = attach
				# Attach the optional hair model to the specified bone.
		if hair_scene:
			print("Creating hair scene")
			_hair_instance = hair_scene.instantiate()
			skeleton.get_node("HairVisuals").add_child(_hair_instance)
	_update_hair_visibility()

func _on_slot_changed(slot: String, index: int, item: Item) -> void:
		## Remove existing model for this slot and attach the new one if any.
	var key := "%s_%d" % [slot, index]
	_clear_slot(key)
	if not item or item.model == null:
		print("no item or no item model")
		_update_hair_visibility()
		return
	var instance: Node3D = item.model.instantiate()
		
	if item.hand_reverse and slot == "weapon":
		slot = "offhand"
		
		
	if slot == "armor":
		_equip_armor(instance, key)
	elif slot in SLOT_BONES:
		print("equipping ", item.item_name, " in ", slot, " slot")
		var attach: Node3D = _attachments[slot]
		attach.add_child(instance)

		# Reset any stray offsets on the instance (and optional visible child)
		instance.transform = Transform3D.IDENTITY
		var mesh := instance.get_node_or_null("MeshInstance3D")
		if mesh:
			mesh.transform = Transform3D.IDENTITY

		# ---- Grip placement ----
		# Expect a child Node3D named "Grip" inside the weapon scene.
		# Author it so its axes match the intended hand axes (Y up, -Z forward).
		var grip: Node3D = instance.get_node_or_null("Grip")
		if grip:
			# Make the instance such that Grip becomes identity in the attachment.
			# (i.e., place/rotate the weapon so Grip aligns with the parent origin/axes)
			instance.transform = grip.transform.affine_inverse()
		else:
			# Fallback if no Grip present: use your authored offsets (radians/local)
			var basis := Basis.from_euler(item.equip_rotation_rads)
			instance.transform = Transform3D(basis, item.equip_position)

		_models[key] = instance
	else:
		# --- Your else case (non-armor, non-bone slot) ---
		instance.position = Vector3(0, 0, 0)
		instance.rotation = Vector3(0, 0, 0)
		skeleton.add_child(instance)

		# Mirror any matching shape keys from Body to the new meshes:
		var body_blends_else := _snapshot_body_blend_shapes()
		_apply_body_blends_to_tree(instance, body_blends_else)

		_models[key] = instance
	_update_hair_visibility()

func _clear_slot(slot: String) -> void:
	var model = _models.get(slot, null)
	if model:
		if model is Array:
			for m in model:
				if is_instance_valid(m):
					m.queue_free()
		elif is_instance_valid(model):
			model.queue_free()
		_models.erase(slot)

# --- Call this inside your EquipmentVisualManager ---

func _equip_armor(root: Node3D, key: String) -> void:
	# 0) Snapshot the player's current body blend-shape values once
	var body_blends := _snapshot_body_blend_shapes()
	print("Body blends: ", body_blends)

	# 1) Extract all meshes from the incoming scene
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(root, meshes)  # <-- your existing collector

	# 2) Reparent/retarget to the player's skeleton
	for m in meshes:
		if m == null:
			continue
		var global_xform: Transform3D = m.global_transform
		skeleton.add_child(m)
		m.global_transform = global_xform
		m.skeleton = m.get_path_to(skeleton)

		# Your existing defaulting (keep if intended)
		m.scale = Vector3(100, 100, 100)
		m.position = Vector3(0, 0, 0)
		m.rotation = Vector3(deg_to_rad(0), deg_to_rad(180), deg_to_rad(0))

		# 3) Apply matching body blend-shape values to this armor mesh
		_apply_body_blends_to_tree(m, body_blends)

	# 4) Clean up the source scene and store references
	root.queue_free()
	_models[key] = meshes


# --- Helpers ---

func _snapshot_body_blend_shapes() -> Dictionary:
	var out := {}
	var body := skeleton.get_node_or_null("Body") as MeshInstance3D
	if body == null or body.mesh == null:
		return out
	var n = body.mesh.get_blend_shape_count()
	for i in range(n):
		var name = body.mesh.get_blend_shape_name(i)
		out[name] = body.get_blend_shape_value(i)  # values live on the instance
	return out

func _apply_body_blends_to_tree(root: Node, body_blends: Dictionary) -> void:
	if root == null:
		return
	# Apply to this node if it's a MeshInstance3D
	if root is MeshInstance3D and root.mesh:
		var mi := root as MeshInstance3D
		var cnt = mi.mesh.get_blend_shape_count()
		for j in range(cnt):
			var bs_name = mi.mesh.get_blend_shape_name(j)
			if body_blends.has(bs_name):
				mi.set_blend_shape_value(j, body_blends[bs_name])
	# Recurse
	for c in root.get_children():
		_apply_body_blends_to_tree(c, body_blends)


# Optional: call this whenever the player's sliders change
func apply_current_body_blends_to_equipment() -> void:
	var body_blends := _snapshot_body_blend_shapes()
	for k in _models.keys():
		for mi in _models[k]:
			_apply_body_blends_to_tree(mi, body_blends)

func _collect_meshes(node: Node, out: Array) -> void:
		## Recursively gather MeshInstance3D nodes from `node` into `out`.
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect_meshes(c, out)

func _update_hair_visibility() -> void:
		## Shows or hides the hair model based on equipped items that request
		## hair to be hidden.  Iterates all items using the EquipmentManager's
		## `get_all_items` helper.  If any item has `hide_hair` set the hair is
		## hidden; otherwise it is shown.
	if not _hair_instance:
		return
	var hide := false
	if equipment:
		for itm in equipment.get_all_items():
			if itm and itm.hide_hair:
				hide = true
				break
	print("hide? ", hide)
	print(_hair_instance.name)
	_hair_instance.visible = not hide
	print(_hair_instance.visible)
