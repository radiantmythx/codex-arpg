extends Node3D
class_name Interactable
## Generic base for non-NPC objects the player can interact with.
##
## Attach to any `Node3D` with a `CollisionShape3D` so the player can
## hover and interact. Objects automatically join the `interactable`
## group and expose a simple highlight when hovered.
##
## `interaction_range` controls how close the player must be to use
## the object. Override `interact(player)` in subclasses to perform
## custom logic when the player presses the **interact** action while
## the object is hovered.

@export var interaction_range: float = 3.0 ## Player must be within this distance to interact.
@export var outline_color: Color = Color.CYAN ## Outline color when hovered.

var _mesh: MeshInstance3D
var _hover_outline_material: ShaderMaterial

const HOVER_OUTLINE_SHADER := preload("res://resources/enemy_hover_outline.gdshader")

func _ready() -> void:
    add_to_group("interactable")
    _mesh = get_node_or_null("MeshInstance3D")
    if _mesh:
        _hover_outline_material = ShaderMaterial.new()
        _hover_outline_material.shader = HOVER_OUTLINE_SHADER
        _hover_outline_material.set_shader_parameter("outline_color", outline_color)

func set_hovered(hovered: bool) -> void:
    ## Toggle the outline when the cursor hovers this interactable.
    if not _mesh:
        return
    _mesh.material_overlay = _hover_outline_material if hovered else null

func interact(player: Node) -> void:
    ## Called by the Player when the **interact** action is pressed
    ## while this object is hovered and within range.
    pass
