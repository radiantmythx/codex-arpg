class_name TileLevelSettings
extends Resource

# Configuration resource consumed by `TileLevelGenerator`.
# Create a `.tres` from this script to define tiles, room/tunnel sizes
# and optional decorations.

const TunnelSize := {
    NONE = 0,
    EXTRA_SMALL = 1,
    SMALL = 2,
    MEDIUM = 3,
    LARGE = 4,
    EXTRA_LARGE = 5,
    GIGANTIC = 6,
}

@export var tiles: Tile9Set
@export var room_count: int = 5
@export var room_min_size: Vector2i = Vector2i(4, 4)
@export var room_max_size: Vector2i = Vector2i(8, 8)
@export var tunnel_size: int = TunnelSize.MEDIUM
@export_range(0.0, 1.0) var obstacle_chance: float = 0.0
# Distance in world units between tile centers.
@export_range(0.1, 4.0) var tile_size: float = 1.0
@export var decorations: Array[LevelDecoration] = []
# Optional fixed seed. Set to 0 to randomize.
@export var seed: int = 0

# Example usage in code:
# var settings := load("res://path/to/your_settings.tres")
# var level := TileLevelGenerator.new().generate(settings)
# add_child(level)
