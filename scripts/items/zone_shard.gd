class_name ZoneShard
extends Item

# Zone shards open a generated level when placed in a ZoneShardSlot and
# activated.  They reuse the standard item/affix system so they can roll
# modifiers that affect the zone.
#
# The actual level is produced by `ZoneGenerator.generate_zone` which reads the
# affixes on the shard and builds a PackedScene.

# Optional description of the zone tier or tileset that could be used when
# generating the level.  For now this is informational only.
@export var zone_type: String = ""
