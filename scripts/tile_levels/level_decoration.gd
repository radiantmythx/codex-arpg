class_name LevelDecoration
extends Resource

# Represents a decoration that may randomly appear on top of floor tiles.
# `frequency` is the chance (0-1) that the decoration spawns on any tile.
@export var scene: PackedScene
@export_range(0.0, 1.0) var frequency: float = 0.0
