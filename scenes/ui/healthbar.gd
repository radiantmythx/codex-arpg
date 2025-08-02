extends Control
class_name Healthbar

var max_health: int = 100
var current_health: int = 100

func _ready():
	update_healthbar()

func update_healthbar():
	$ProgressBar.max_value = max_health
	$ProgressBar.value = current_health
	#print("Updated healthbar: ", current_health, " / ", max_health)

func set_health(value: int, valueMax: int):
	current_health = clamp(value, 0, valueMax)
	max_health = valueMax
	update_healthbar()
