extends GPUParticles3D

func _ready():
	call_deferred("_start")

func _start():
	# Ensure unique resources per instance
	if process_material:
		process_material.resource_local_to_scene = true
	for i in get_draw_passes():
		var mesh := get_draw_pass_mesh(i)
		if mesh:
			mesh = mesh.duplicate(true)     # duplicate the Mesh
			set_draw_pass_mesh(i, mesh)
			# duplicate and tweak the surface material(s)
			for s in mesh.get_surface_count():
				var mat := mesh.surface_get_material(s)
				if mat:
					mat = mat.duplicate(true)
					# Important: keep transparent & never write depth for additive bursts
					if mat is BaseMaterial3D:
						mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
					mesh.surface_set_material(s, mat)
	print("On hit effect!")
	await get_tree().process_frame  # guarantees we're in the scene and visible
	restart()
	emitting = true
	var total_time = lifetime + preprocess
	var timer = get_tree().create_timer(total_time + 0.1)
	timer.timeout.connect(queue_free)
