class_name Equipment
extends Item

## Basic equipment item that adds flat defensive stats when equipped.
## `EquipmentManager` applies these to the wearer's `Stats`.
@export var base_evasion: float = 0.0
@export var base_block: float = 0.0
@export var base_damage_reduction: float = 0.0
@export var base_energy_shield: float = 0.0
