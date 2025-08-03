extends ProjectileSkill
class_name IcicleBlastSkill

const Buff = preload("res://scripts/buff.gd")
const Stats = preload("res://scripts/stats.gd")

func _init():
        on_hit_buff = Buff.new()
        on_hit_buff.duration = 2.0
        on_hit_buff.stat_bonuses = {"move_speed_inc": -10.0}
        damage_type = Stats.DamageType.ICE
