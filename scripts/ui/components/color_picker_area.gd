extends VBoxContainer

@export var label_text:String
@export var player_material_name:String


func _ready():
	$Label.text = label_text

func _on_color_picker_color_changed(color):
	GlobalPlayerHandler.set_player_texture_color_override(player_material_name, color)
