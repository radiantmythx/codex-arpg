extends TextureButton

@export var text_color: Color = Color("ffffff")
@export var hover_text_color: Color = Color("ffff00")
@export var label_text: String

@onready var label: Label = $Label

func _ready() -> void:
	# Ensure the button gets hover even over the Label
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = label_text

	# If the Label has LabelSettings, make sure it's not a shared resource
	if label.label_settings:
		# Duplicate so this node gets its own copy
		label.label_settings = label.label_settings.duplicate()
		label.label_settings.resource_local_to_scene = true
		label.label_settings.font_color = text_color
	else:
		# Fall back to per-node override
		label.add_theme_color_override("font_color", text_color)

	# Connect hover signals per instance
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	if label.label_settings:
		label.label_settings.font_color = hover_text_color
	else:
		label.add_theme_color_override("font_color", hover_text_color)

func _on_mouse_exited() -> void:
	if label.label_settings:
		label.label_settings.font_color = text_color
	else:
		label.add_theme_color_override("font_color", text_color)
