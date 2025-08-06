class_name ZoneGenerator
extends Resource

# Builds a simple flat zone populated with enemies using one or more Zone Shards.
# The returned PackedScene can be instanced and the player warped to it.

const GeneratedZone = preload("res://scripts/zones/generated_zone.gd")

@export var enemy_pack_scene: PackedScene
@export var boss_scene: PackedScene
@export var base_pack_count: int = 5
@export var plane_size: float = 20.0

func generate_zone(shards: Array[ZoneShard]) -> PackedScene:
    var mods := _collect_modifiers(shards)
    var root := GeneratedZone.new()
    root.mods = mods

    var plane := MeshInstance3D.new()
    var mesh := PlaneMesh.new()
    mesh.size = Vector2(plane_size, plane_size)
    plane.mesh = mesh
    root.add_child(plane)

    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var pack_count := int(base_pack_count * mods.get("spawn_mult", 1.0))
    for i in range(pack_count):
        if enemy_pack_scene:
            var pack = enemy_pack_scene.instantiate()
            var x = rng.randf_range(-plane_size * 0.5, plane_size * 0.5)
            var z = rng.randf_range(-plane_size * 0.5, plane_size * 0.5)
            pack.position = Vector3(x, 0, z)
            root.add_child(pack)

    if boss_scene:
        var boss = boss_scene.instantiate()
        boss.position = Vector3.ZERO
        root.add_child(boss)

    var packed := PackedScene.new()
    packed.pack(root)
    return packed

func _collect_modifiers(shards: Array[ZoneShard]) -> Dictionary:
    var mods := {"spawn_mult": 1.0, "enemy_hp_inc": 0.0, "enemy_fire_damage": 0.0}
    for shard in shards:
        if not shard:
            continue
        for aff in shard.affixes:
            for key in aff.stat_bonuses.keys():
                var v = aff.stat_bonuses[key]
                match key:
                    "enemy_spawn_inc":
                        mods.spawn_mult *= 1.0 + v / 100.0
                    "enemy_hp_inc":
                        mods.enemy_hp_inc += v
                    "enemy_fire_damage":
                        mods.enemy_fire_damage += v
    return mods
