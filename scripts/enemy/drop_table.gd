class_name DropTable
extends Resource

# Global loot table usable by multiple enemies.
# Each entry is a dictionary: {"item": Item, "chance": float, "amount": int}
# When an enemy dies, all assigned DropTables are merged and rolled.
@export var entries: Array[Dictionary] = []
