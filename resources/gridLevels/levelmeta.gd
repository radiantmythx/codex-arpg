# LevelMeta.gd
extends Resource
class_name LevelMeta

@export var title: String = "Unknown Area"
@export var subtitle: String = ""
@export var biome: String = ""
@export var difficulty: int = 1
@export var music_stream: AudioStream
@export var seed: int = 0
@export var notes: String = ""

# Optional: computed/UI-friendly fields
func to_dict() -> Dictionary:
	return {
		"title": title,
		"subtitle": subtitle,
		"biome": biome,
		"difficulty": difficulty,
		"seed": seed,
		"notes": notes
	}
