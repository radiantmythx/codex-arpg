class_name Buff
extends Resource

@export var duration: float = 0.0
@export var main_stat_bonuses: Dictionary = {}
@export var stat_bonuses: Dictionary = {}
@export var flags: Array[String] = []

# NEW: Visuals for this buff
# A scene that will be attached to (and move with) the entity while the buff is active.
@export var fx_scene: PackedScene
# A material that will be overlayed on all MeshInstance3D descendants of the entity.
# It will be *stacked* (via next_pass) on top of any existing overlays and removed when the buff expires.
@export var overlay_material: Material

# Optional: where to attach the fx (default: buff owner root)
@export var fx_attach_path: NodePath
# Optional: local offset for the fx instance (e.g., slightly above the feet)
@export var fx_local_offset: Vector3 = Vector3.ZERO

func _create_affix() -> Affix:
	var a := Affix.new()
	a.main_stat_bonuses = main_stat_bonuses.duplicate()
	a.stat_bonuses = stat_bonuses.duplicate()
	a.flags = flags.duplicate()
	return a
