extends Button

@export var hair_scene:PackedScene
@export var button_label_text:String
@export var button_image:Texture2D

func _ready():
	$HairImage.texture = button_image
	$Label.text = button_label_text

func _on_toggled(toggled_on):
	if(toggled_on):
		GlobalPlayerHandler.set_player_hair(hair_scene)
