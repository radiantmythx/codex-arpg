class_name Tile9Set
extends Resource

# Defines the nine tile scenes used by the tile level generator.
# These scenes can be any Node type. They will be instanced and
# positioned on a grid based on the generated layout.
#
#      corner_nw  edge_n  corner_ne
#      edge_w     center  edge_e
#      corner_sw  edge_s  corner_se
#
# Assign scenes for each slot when creating a `.tres` resource.
@export var center: PackedScene
@export var edge_n: PackedScene
@export var edge_s: PackedScene
@export var edge_e: PackedScene
@export var edge_w: PackedScene
@export var corner_ne: PackedScene
@export var corner_nw: PackedScene
@export var corner_se: PackedScene
@export var corner_sw: PackedScene
