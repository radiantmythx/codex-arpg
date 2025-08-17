class_name DefaultTileDecoration
extends Resource

# Data describing decorative meshes placed on default (non-level) tiles.
# Each entry spawns instances of `mesh` using a MultiMesh so that large
# amounts of foliage or props can be drawn efficiently.
# `frequency` is treated as the chance that a given tile-sized area
# spawns an instance of the mesh.
@export var mesh: Mesh
@export_range(0.0, 1.0) var frequency: float = 0.0
