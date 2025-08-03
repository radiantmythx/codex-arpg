class_name Skill
extends Resource

@export var name: String = ""
@export var icon: Texture2D
@export var mana_cost: float = 0.0
@export var cooldown: float = 0.0
@export var duration: float = 0.0
@export var move_multiplier: float = 1.0
@export var damage_type: Stats.DamageType = Stats.DamageType.PHYSICAL
@export var tags: Array[String] = []

func perform(user):
		pass
