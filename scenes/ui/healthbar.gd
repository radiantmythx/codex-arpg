extends Control
class_name Healthbar

var max_health: float = 100
var current_health: float = 100
var mana: float = 0
var max_mana: float = 0

func _ready():
	update_healthbar()

func update_healthbar():
	$ProgressBar.max_value = max_health
	$ProgressBar.value = current_health
	#print("Updated healthbar: ", current_health, " / ", max_health)
	if mana > 0 and $ManaBar:
		$ManaBar.max_value = max_mana
		$ManaBar.value = mana

func set_health(value: int, valueMax: int):
	current_health = clamp(value, 0, valueMax)
	max_health = valueMax
	update_healthbar()
	
func set_mana(value: float, valueMax: float):
	mana = clamp(value, 0, valueMax)
	max_mana = valueMax
	update_healthbar()
