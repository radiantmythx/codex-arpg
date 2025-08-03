extends Skill
class_name AuraSkill

@export var mana_reserve_percent: float = 0.0 # Percentage of max mana reserved while active
@export var buff: Buff # Buff applied while aura is active
@export var aura_effect: PackedScene # Optional visual effect attached to user

var _active: Dictionary = {}

func perform(user):
		if user == null:
				return
		if _active.has(user):
				_deactivate(user)
		else:
				var reserve = 0.0
				if "max_mana" in user:
						reserve = user.max_mana * mana_reserve_percent
						if user.mana < reserve:
								return
						user.mana -= reserve
						if "reserved_mana" in user:
								user.reserved_mana += reserve
				if buff and user.has_method("add_buff"):
						user.add_buff(buff)
				var effect
				if aura_effect:
						effect = aura_effect.instantiate()
						user.add_child(effect)
				_active[user] = {"reserve": reserve, "effect": effect}

func _deactivate(user):
		var data = _active.get(user, null)
		if data == null:
				return
		if buff and user.has_method("remove_buff"):
				user.remove_buff(buff)
		if data.effect and is_instance_valid(data.effect):
				data.effect.queue_free()
		if "mana" in user:
				user.mana += data.reserve
				if "reserved_mana" in user:
						user.reserved_mana -= data.reserve
						user.mana = min(user.mana, user.max_mana - user.reserved_mana)
		_active.erase(user)
