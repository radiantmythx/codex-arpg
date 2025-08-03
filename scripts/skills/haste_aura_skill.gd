extends AuraSkill
class_name HasteAuraSkill

const BuffInst = preload("res://scripts/buff.gd")

func _init():
		buff = BuffInst.new()
		buff.stat_bonuses = {"move_speed_inc": 20.0}
		mana_reserve_percent = 0.35
