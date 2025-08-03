extends Skill
class_name ComboSkill

@export var skills: Array[Skill] = []

func perform(user):
    for s in skills:
        if s:
            s.perform(user)
