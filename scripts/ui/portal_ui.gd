extends Control

signal travel_requested
signal closed

@export var go_button:Button
@export var x_button:Button

func _ready():
	go_button.pressed.connect(_on_travel_pressed)
	x_button.pressed.connect(_on_close)

func _on_travel_pressed():
	print("hehe ye")
	emit_signal("travel_requested")

func _on_close():
	emit_signal("closed")

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		emit_signal("closed")
