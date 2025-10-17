extends CharacterBody3D
## Simple non-combat character that the player can interact with.
##
## NPCs share targeting behaviour with enemies so the hover UI and outline
## shader work the same way.  When clicked within `interaction_range` the
## conversation UI is opened and the game is paused.
##
## To create an NPC in a scene:
## 1. Add a `CharacterBody3D` and attach this script.
## 2. Give it a `MeshInstance3D` and `CollisionShape3D` like `scenes/enemy.tscn`.
## 3. Optionally tweak the exported properties below in the inspector.
##
## Dialogue lines can be edited directly in the inspector. Each entry in
## `dialogue_lines` is displayed sequentially when the player chooses "Talk".

@export var enemy_name: String = "Villager" ## Display name used by the target UI.
@export var enemy_level: int = 1 ## Arbitrary level shown beside the name.
@export var interaction_range: float = 3.0 ## Player must be this close to talk.
@export var dialogue_lines: Array[String] = ["Hello there!"]
@export var can_trade: bool = true ## When false the Trade option is hidden.

# Minimal health fields so the existing target display can show a bar.
@export var max_health: float = 1.0
var current_health: float

var _mesh: MeshInstance3D
var _hover_outline_material: ShaderMaterial

const HOVER_OUTLINE_SHADER := preload("res://resources/enemy_hover_outline.gdshader")

func _ready() -> void:
	current_health = max_health
	add_to_group("npc")
	_mesh = get_node_or_null("MeshInstance3D")
	if _mesh:
		_hover_outline_material = ShaderMaterial.new()
		_hover_outline_material.shader = HOVER_OUTLINE_SHADER
		_hover_outline_material.set_shader_parameter("outline_color", Color.GREEN)

func set_hovered(hovered: bool) -> void:
	## Toggle the green outline when the mouse hovers this NPC.
	if not _mesh:
		return
	_mesh.material_overlay = _hover_outline_material if hovered else null
