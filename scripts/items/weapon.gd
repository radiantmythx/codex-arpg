class_name Weapon
extends Equipment

enum WeaponType { MELEE, PROJECTILE, SPELL }

# Base damage range the weapon contributes when used with compatible skills.
@export var base_damage_low: float = 0.0
@export var base_damage_high: float = 0.0

# Primary damage type of the weapon.  Skills using the weapon will inherit
# this type when its base damage is applied.
@export var damage_type: Stats.DamageType = Stats.DamageType.PHYSICAL

# Attack speed multiplier applied to compatible skills. A value of 1.0 means
# no change, 1.3 makes skills 30% faster, etc.
@export var speed: float = 1.0

# Classification used to determine which skills can benefit from this weapon.
@export var weapon_type: WeaponType = WeaponType.MELEE

# Optional ability granted when the weapon is equipped.  Players may override
# their current main skill with this default when the weapon is worn.
@export var default_skill: Skill
