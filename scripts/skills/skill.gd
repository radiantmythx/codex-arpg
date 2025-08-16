class_name Skill
extends Resource

@export var name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var mana_cost: float = 0.0
@export var cooldown: float = 0.0
@export var duration: float = 0.0
@export var move_multiplier: float = 1.0
@export var damage_type: Stats.DamageType = Stats.DamageType.PHYSICAL
@export var base_damage_low: float = 0.0
@export var base_damage_high: float = 0.0
@export var tags: Array[String] = []
@export var animation_name: StringName = &""
@export var attack_time: float = 0.0 ## Seconds into the animation when the attack is applied.
@export var cancel_time: float = 0.0 ## Seconds into the animation when the remainder can be cancelled.

func perform(user):
	pass

# Helper to construct the damage dictionary passed to Stats.compute_damage.
# By default this uses the skill's own base damage values but, if the user
# (player or enemy) exposes a `get_base_damage_dict(tags)` method, those values
# are merged in.  This lets enemies define innate damage ranges and allows
# players to contribute weapon damage only when the skill's tags match the
# weapon type.
func _build_base_damage_dict(user) -> Dictionary:
		var dict: Dictionary = {}
		if user and user.has_method("get_base_damage_dict"):
				dict = user.get_base_damage_dict(tags)
		dict[damage_type] = Vector2(base_damage_low, base_damage_high)
		return dict
