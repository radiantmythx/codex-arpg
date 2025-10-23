extends Button
class_name KnownSkillButton

@export var skill:Skill

func _ready():
	if(skill):
		$TextureRect.texture = skill.icon
		tooltip_text = "%s\n%s" % [skill.name, skill.description]
		


func _update_skill(new_skill:Skill):
	$TextureRect.texture = new_skill.icon
	skill = new_skill
	if skill:
		tooltip_text = "%s\n%s" % [skill.name, skill.description]
	else:
		tooltip_text = ""


func _on_toggled(toggled_on):
	GlobalPlayerHandler.set_player_set_skill_choice(skill)
