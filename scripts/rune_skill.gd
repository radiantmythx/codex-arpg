extends Skill
class_name RuneSkill

var base_skill: Skill
var rune_affixes: Array[Affix] = []

func _init(base: Skill = null, affixes: Array[Affix] = []):
    base_skill = base
    rune_affixes = affixes
    if base_skill:
        name = base_skill.name
        icon = base_skill.icon
        mana_cost = base_skill.mana_cost
        cooldown = base_skill.cooldown
        duration = base_skill.duration
        move_multiplier = base_skill.move_multiplier
        damage_type = base_skill.damage_type
        tags = base_skill.tags.duplicate()
    _apply_affix_modifiers()

func _apply_affix_modifiers():
    for a in rune_affixes:
        for key in a.stat_bonuses.keys():
            var val = a.stat_bonuses[key]
            match key:
                "mana_cost_add":
                    mana_cost += val
                "mana_cost_inc":
                    mana_cost *= (1.0 + val / 100.0)
                "cooldown_add":
                    cooldown += val
                "cooldown_inc":
                    cooldown *= (1.0 + val / 100.0)
                "duration_add":
                    duration += val
                "duration_inc":
                    duration *= (1.0 + val / 100.0)
                "move_multiplier_add":
                    move_multiplier += val
                "move_multiplier_inc":
                    move_multiplier *= (1.0 + val / 100.0)

func perform(user):
    if base_skill == null:
        return
    if user and user.has("stats"):
        for a in rune_affixes:
            user.stats.apply_affix(a)
        base_skill.perform(user)
        for a in rune_affixes:
            user.stats.remove_affix(a)
    else:
        base_skill.perform(user)
