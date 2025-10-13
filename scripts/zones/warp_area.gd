extends Node3D

@export_enum("North", "South", "East", "West") var direction: String
@export var warp_vfx:Node3D
@export var warp_vfx_mesh:MeshInstance3D
var _energy_mat:Material

@export var cell_offset: Vector2i

var active_energy:bool = false
var _player

var burn_warp = false


func _ready():
	burn_warp = false
	warp_vfx.visible=false
	_energy_mat = warp_vfx_mesh.get_active_material(0)
	if _energy_mat and _energy_mat is ShaderMaterial:
		_energy_mat = _energy_mat as ShaderMaterial
		_energy_mat.set_shader_parameter("Energy Power", 0.01)
	if cell_offset == Vector2i():
		match direction:
			"North": cell_offset = Vector2i(0, 1)
			"South": cell_offset = Vector2i(0,  -1)
			"East":  cell_offset = Vector2i(1,  0)
			"West":  cell_offset = Vector2i(-1, 0)
		
func _process(delta):
	if(active_energy):
		var distance = global_position.distance_to(_player.global_position)
		var proximity = clamp(1.0 - (distance / 2.5), 0, 1)
		var energy = lerp(0.2, 1.0, proximity)
		_energy_mat.set_shader_parameter("EnergyPower", energy)
	pass


func _on_warp_trigger_body_entered(body):
	print("Body has entered!")
	if(body.is_in_group("player")):
		if not WorldGrid.can_accept_warp(): return
		WorldGrid.request_warp(cell_offset, direction)

func _on_energy_trigger_body_entered(body):
	if(body.is_in_group("player")):
		warp_vfx.visible = true
		active_energy = true
		_player = body
		_energy_mat.set_shader_parameter("EnergyPower", 0.01)


func _on_energy_trigger_body_exited(body):
	if(body.is_in_group("player")):
		warp_vfx.visible = false
		active_energy = false
		_energy_mat.set_shader_parameter("EnergyPower", 0.01)
