extends MeshInstance3D

func _ready():
	print("I am created!")

func _process(delta):
	print(global_position)
	print(scale)
