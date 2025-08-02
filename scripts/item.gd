extends Resource
class_name Item

# Basic item resource used by the inventory and equipment systems.
# Items may represent consumables or equippable gear depending on their
# configuration.  Equippable items expose an `equip_slot` and a list of
# `Affix` resources that describe any bonuses the item grants when equipped.

@export var item_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var max_stack: int = 1

# Name of the equipment slot this item fits in. Leave empty for non-equipable
# items such as consumables.  Example values: "weapon", "armor", "ring".
@export var equip_slot: String = ""

# Affixes attached to this item. Each affix modifies player statistics when
# the item is equipped.  Affixes can be authored in the editor and added to an
# item to create variations without additional code.
@export var affixes: Array[Affix] = []
