extends Button

@export var information_text_area:RichTextLabel
@export var button_image:Texture2D
@export var hover_text:String

var _prev_text

func _ready():
	$GemImage.texture = button_image


func _on_gem_image_mouse_entered():
	_prev_text = information_text_area.text
	information_text_area.text = hover_text.replace("\\n", "\n")


func _on_gem_image_mouse_exited():
	information_text_area.text = _prev_text
