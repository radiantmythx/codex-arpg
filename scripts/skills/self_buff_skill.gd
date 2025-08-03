extends Skill
class_name SelfBuffSkill

@export var buff: Buff

func perform(user):
    if user == null or buff == null:
        return
    if user.has_method("add_buff"):
        user.add_buff(buff)
