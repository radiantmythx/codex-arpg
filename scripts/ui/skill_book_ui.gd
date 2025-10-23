extends CanvasLayer
class_name SkillBookUI

var _open:bool=false
var _player:PlayerCharacter
@export var KnownSkillsFlowContainer:FlowContainer
@export var SkillButtonScene:PackedScene

func _ready():
	visible = false
	_open = false
	_player = GlobalPlayerHandler.player
	
func open() -> void:
	_open = true
	visible = true
	_update_skills()
	#_shift_camera(true)


func close() -> void:
	_open = false
	visible = false
	#_shift_camera(false)

func _update_skills():
	var skill_array = _player.all_known_skills
	for c in skill_array:
		print(c.name)
	for c in KnownSkillsFlowContainer.get_children():
		c.queue_free()
	for known_skill:Skill in skill_array:
		var newButton:KnownSkillButton = SkillButtonScene.instantiate()
		newButton._update_skill(known_skill)
		KnownSkillsFlowContainer.add_child(newButton)
