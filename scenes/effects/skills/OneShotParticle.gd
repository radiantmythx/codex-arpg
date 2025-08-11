extends GPUParticles3D

func _ready():
	emitting = true
	var total_time = lifetime + preprocess
	var timer = get_tree().create_timer(total_time + 0.1)
	timer.timeout.connect(queue_free)
