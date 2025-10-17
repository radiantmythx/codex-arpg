extends Label
@export var player:PlayerCharacter

func _ready():
	pass
	
func _process(delta):
	text = str(player.global_position.x) + "\n" + str(player.global_position.z)
