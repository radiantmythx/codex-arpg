extends CanvasLayer
class_name InventoryUI

@export var slots_parent_path: NodePath
@export var camera_path: NodePath
@export var camera_shift: float = 3.0

var _slots: Array = []
var _inventory: Inventory
var _camera: Camera3D
var _camera_base_pos: Vector3
var _open := false

func _ready() -> void:
        if slots_parent_path != NodePath():
                var parent = get_node(slots_parent_path)
                _slots = parent.get_children()
        if camera_path != NodePath():
                _camera = get_node(camera_path)
                if _camera:
                        _camera_base_pos = _camera.position
        visible = false

func bind_inventory(inv: Inventory) -> void:
        _inventory = inv
        if _inventory:
                _inventory.connect("item_added", _on_inventory_changed)
                _inventory.connect("item_removed", _on_inventory_changed)
                _update_slots()

func toggle() -> void:
        if _open:
                close()
        else:
                open()

func open() -> void:
        _open = true
        visible = true
        _shift_camera(true)
        _update_slots()

func close() -> void:
        _open = false
        visible = false
        _shift_camera(false)

func _shift_camera(open: bool) -> void:
        if not _camera:
                return
        var target := _camera_base_pos
        if open:
                target.x += camera_shift
        var tween := create_tween()
        tween.tween_property(_camera, "position", target, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_inventory_changed(_item: Item) -> void:
        _update_slots()

func _update_slots() -> void:
        if not _inventory:
                return
        var items := _inventory.get_items()
        var index := 0
        for item in items.keys():
                if index >= _slots.size():
                        break
                var slot = _slots[index]
                if slot.has_method("set_item"):
                        slot.set_item(item)
                if slot.has_method("set_amount"):
                        slot.set_amount(items[item])
                index += 1
        for i in range(index, _slots.size()):
                var slot = _slots[i]
                if slot.has_method("set_item"):
                        slot.set_item(null)
                if slot.has_method("set_amount"):
                        slot.set_amount(0)
