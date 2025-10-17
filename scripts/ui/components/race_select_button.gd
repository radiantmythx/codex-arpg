extends TextureButton

@export var information_text_area:RichTextLabel
@export var label_text:String
@export var hover_text:String
@export var added_race_visuals:Array[PackedScene]

var _prev_text

func _ready():
	$Label.text = label_text

func _on_mouse_entered():
	_prev_text = information_text_area.text
	information_text_area.text = hover_text.replace("\\n", "\n")


func _on_mouse_exited():
	information_text_area.text = _prev_text


func _on_toggled(toggled_on):
	if(toggled_on):
		GlobalPlayerHandler.update_player_race(label_text, added_race_visuals)
