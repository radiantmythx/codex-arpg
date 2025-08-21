class_name Equipment
extends Item

## Basic equipment item that adds flat defensive stats when equipped.
## `EquipmentManager` applies these to the wearer's `Stats`.
@export var base_evasion: float = 0.0
@export var base_block: float = 0.0
@export var base_damage_reduction: float = 0.0
@export var base_energy_shield: float = 0.0


## Returns a formatted string describing any inherent defensive stats this
## piece of equipment provides. Stats with values of ``0`` are omitted so only
## meaningful information is displayed in tooltips.
func get_base_stat_text() -> String:
		var lines: Array[String] = []
		if base_block > 0:
				lines.append("Base Block: %d%%" % int(base_block))
		if base_evasion > 0:
				lines.append("Base Evasion: %d%%" % int(base_evasion))
		if base_energy_shield > 0:
				lines.append("Base Energy Shield: %d" % int(base_energy_shield))
		if base_damage_reduction > 0:
				lines.append("Base Damage Reduction: %d%%" % int(base_damage_reduction))
		return "\n".join(lines)
