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
				if bone_find == -1:
					print("COULD NOT FIND SKELETON")
				var bone_name: String = SLOT_BONES[slot]
				var attach := BoneAttachment3D.new()
				attach.bone_name = bone_name
				skeleton.add_child(attach)
				print("Set up attach slot for slot: ", slot)
				_attachments[slot] = attach
				# Attach the optional hair model to the specified bone.
				if hair_scene:
					_hair_instance = hair_scene.instantiate()
					skeleton.add_child(_hair_instance)
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
		if slot == "armor":
				_equip_armor(instance, key)
		elif slot in SLOT_BONES:
						print("equipping ", item.item_name, " in ", slot, " slot")
						_attachments[slot].add_child(instance)
						var local_xform := Transform3D(Basis.from_euler(item.equip_rotation_rads), item.equip_position)
						instance.transform = local_xform
						_models[key] = instance
		else:
						skeleton.add_child(instance)
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

func _equip_armor(root: Node3D, key: String) -> void:
		## Attach an armour model by retargeting all MeshInstance3D nodes to the
		## player's skeleton. The original scene is freed after extraction.
		print("equipping armor?")
		var meshes: Array = []
		_collect_meshes(root, meshes)
		for m in meshes:
				var global_xform: Transform3D = m.global_transform
				skeleton.add_child(m)
				m.global_transform = global_xform
				m.skeleton = m.get_path_to(skeleton)
				m.scale = Vector3(100, 100, 100)
		root.queue_free()
		_models[key] = meshes

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
