extends Skill
class_name SelfBuffSkill

@export var buff: Buff

func perform(user) -> void:
	if user == null or buff == null:
		return
	if user.has_method("add_buff"):
		var inst := _prepare_buff_instance(buff, user)
		if inst:
			user.add_buff(inst)
