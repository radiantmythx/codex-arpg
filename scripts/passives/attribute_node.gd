class_name AttributeNode
extends PassiveNode

@export var stat: Stats.MainStat = Stats.MainStat.BODY
@export var amount: int = 1

var _affix: Affix = null

func apply_effect(player) -> void:
	if player and player.stats:
		_affix = Affix.new()
		_affix.main_stat_bonuses[stat] = amount
		player.stats.apply_affix(_affix)

func remove_effect(player) -> void:
	if player and player.stats and _affix:
		player.stats.remove_affix(_affix)
		_affix = null
