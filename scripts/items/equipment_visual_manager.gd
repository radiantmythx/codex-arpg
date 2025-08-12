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

func _ready() -> void:
    if equipment:
        equipment.connect("slot_changed", _on_slot_changed)
    # Pre-create attachment points for mapped slots.
    if skeleton:
        for slot in SLOT_BONES.keys():
            var bone_name: String = SLOT_BONES[slot]
            var attach := BoneAttachment3D.new()
            attach.bone_name = bone_name
            skeleton.add_child(attach)
            _attachments[slot] = attach

func _on_slot_changed(slot: String, item: Item) -> void:
    ## Remove existing model for this slot and attach the new one if any.
    _clear_slot(slot)
    if not item or item.model == null:
        return
    var instance: Node3D = item.model.instantiate()
    instance.transform = item.equip_transform
    if slot == "armor":
        _equip_armor(instance)
    elif slot in SLOT_BONES:
        _attachments[slot].add_child(instance)
        _models[slot] = instance
    else:
        skeleton.add_child(instance)
        _models[slot] = instance

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

func _equip_armor(root: Node3D) -> void:
    ## Attach an armour model by retargeting all MeshInstance3D nodes to the
    ## player's skeleton.  The original scene is freed after extraction.
    var meshes: Array = []
    _collect_meshes(root, meshes)
    for m in meshes:
        var global_xform: Transform3D = m.global_transform
        skeleton.add_child(m)
        m.global_transform = global_xform
        m.skeleton = m.get_path_to(skeleton)
    root.queue_free()
    _models["armor"] = meshes

func _collect_meshes(node: Node, out: Array) -> void:
    ## Recursively gather MeshInstance3D nodes from `node` into `out`.
    if node is MeshInstance3D:
        out.append(node)
    for c in node.get_children():
        _collect_meshes(c, out)
