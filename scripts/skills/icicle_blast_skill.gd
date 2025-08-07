extends ProjectileSkill
class_name IcicleBlastSkill

const BuffInst = preload("res://scripts/skills/buff.gd")
const StatsInst = preload("res://scripts/stats.gd")

func _init():
	on_hit_buff = BuffInst.new()
	on_hit_buff.duration = 2.0
	on_hit_buff.stat_bonuses = {"move_speed_inc": -10.0}
	damage_type = StatsInst.DamageType.ICE
