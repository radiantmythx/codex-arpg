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
@export var default_tile: PackedScene  # tile used when a space has no normal tile
@export var draw_default_tiles: bool = false  # place `default_tile` in empty positions
@export var draw_default_tiles_outside_level: bool = false  # surround the level with huge default tiles
@export_range(1.0, 100.0) var default_tile_outside_scale: float = 8.0  # size multiplier for outside tiles
@export var default_decorations: Array[DefaultTileDecoration] = []  # MultiMesh decorations for default tiles

# --- Room and tunnel decorations -------------------------------------------
# Decorations applied to floor tiles inside rooms. These are PackedScenes
# instantiated per tile similar to the old `decorations` field.
@export var room_decorations: Array[LevelDecoration] = []
# Decorations applied to corridor tiles.
@export var tunnel_decorations: Array[LevelDecoration] = []
# MultiMesh decorations for rooms, allowing large numbers of repeated meshes.
@export var room_multimesh_decorations: Array[DefaultTileDecoration] = []
# MultiMesh decorations for tunnels.
@export var tunnel_multimesh_decorations: Array[DefaultTileDecoration] = []

# Special decorations for the player's starting room.
@export var player_room_decorations: Array[LevelDecoration] = []
@export var player_room_multimesh_decorations: Array[DefaultTileDecoration] = []
# When true, player rooms also receive the normal room decorations defined
# above.
@export var player_inherit_room_decorations: bool = true
@export var player_inherit_room_multimesh: bool = true

# Special decorations for the boss room.
@export var boss_room_decorations: Array[LevelDecoration] = []
@export var boss_room_multimesh_decorations: Array[DefaultTileDecoration] = []
# When true, boss rooms also receive the normal room decorations defined above.
@export var boss_inherit_room_decorations: bool = true
@export var boss_inherit_room_multimesh: bool = true
# Optional fixed seed. Set to 0 to randomize.
@export var seed: int = 0

# --- Level bounds ----------------------------------------------------------
# Maximum size of the generated level in tile coordinates. Rooms are
# positioned so their rectangles fit within these dimensions. Any tiles or
# corridors carved outside the bounds are discarded.
@export var level_size: Vector2i = Vector2i(100, 100)

# --- Enemy spawning --------------------------------------------------------
# Collection of enemy scenes that may appear in rooms.
@export var room_enemy_scenes: Array[PackedScene] = []
# Enemy scenes that may appear in tunnels.
@export var tunnel_enemy_scenes: Array[PackedScene] = []
# If true, enemies listed for rooms are also eligible to spawn in tunnels.
@export var tunnels_use_room_enemies: bool = true
# Chance per valid center tile to spawn an enemy. Values near 0 produce sparse
# encounters while 1.0 fills every available tile.
@export_range(0.0, 1.0) var enemy_density: float = 0.0

# Optional boss scene placed at the farthest room from the player spawn. If
# left empty a simple Node3D marker named "BossSpawn" will be added instead.
@export var boss_scene: PackedScene

# Example usage in code:
# var settings := load("res://path/to/your_settings.tres")
# var level := TileLevelGenerator.new().generate(settings)
# add_child(level)
