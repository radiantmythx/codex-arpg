class_name GeneratedZone
extends Node3D

# Holds a dictionary of modifiers derived from the Zone Shards used to open
# this zone.  When the zone enters the scene tree it applies the modifiers to
# all enemy instances under it.

var mods: Dictionary = {}

const Stats = preload("res://scripts/stats.gd")

func _ready() -> void:
	_apply_mods()

func _apply_mods() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_inside_tree() and is_ancestor_of(enemy):
			_apply_enemy_mods(enemy)

func _apply_enemy_mods(enemy) -> void:
	var hp_inc = mods.get("enemy_hp_inc", 0.0)
	if hp_inc != 0.0:
		enemy.stats.base_max_health *= 1.0 + hp_inc / 100.0
		enemy.max_health = enemy.stats.get_max_health()
		enemy.current_health = enemy.max_health
	var fire_add = mods.get("enemy_fire_damage", 0.0)
	if fire_add != 0.0:
		enemy.stats.base_damage[Stats.DamageType.SOLAR] = enemy.stats.base_damage.get(Stats.DamageType.SOLAR, 0.0) + fire_add
