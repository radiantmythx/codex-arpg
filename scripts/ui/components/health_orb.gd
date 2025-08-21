extends TextureRect
class_name HealthOrb

@onready var mat: ShaderMaterial = material as ShaderMaterial

func update_health(current: float, maximum: float) ->void:
	if maximum <= 0.0:
		mat.set_shader_parameter("health_ratio", 0.0)
		return
	var ratio: float = clamp(current / maximum, 0.0, 1.0)
	mat.set_shader_parameter("health_ratio", ratio)
