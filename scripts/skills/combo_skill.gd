extends Skill
class_name ComboSkill

@export var skills: Array[Skill] = []

func perform(user) -> void:
if user == null:
return
for s in skills:
if s:
s.perform(user)
