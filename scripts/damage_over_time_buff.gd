class_name DamageOverTimeBuff
extends Buff

# Base damage range dealt each second before affix modifiers
@export var base_damage_low: float = 0.0
@export var base_damage_high: float = 0.0
@export var damage_type: Stats.DamageType = Stats.DamageType.PHYSICAL

# Final damage per second after modifiers, computed when applied
var damage_per_second: float = 0.0
