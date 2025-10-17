extends VBoxContainer

@export var label_text:String
@export var shape_key_mod_string:String

func _ready():
	$Label.text = label_text
	


func _on_h_slider_value_changed(value):
	GlobalPlayerHandler.set_player_blendshape(shape_key_mod_string, value)
