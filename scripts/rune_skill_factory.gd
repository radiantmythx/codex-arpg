class_name RuneSkillFactory

# Preload base skill resources for rune combinations
const STRIKE_SKILL = preload("res://resources/skills/rune_strike.tres")
const BUFF_SKILL = preload("res://resources/skills/rune_buff.tres")
const AREA_SKILL = preload("res://resources/skills/rune_area.tres")
const TIME_SKILL = preload("res://resources/skills/rune_time.tres")
const STRIKE_BUFF_SKILL = preload("res://resources/skills/rune_strike_buff.tres")
const STRIKE_AREA_SKILL = preload("res://resources/skills/rune_strike_area.tres")
const STRIKE_TIME_SKILL = preload("res://resources/skills/rune_strike_time.tres")
const BUFF_AREA_SKILL = preload("res://resources/skills/rune_buff_area.tres")
const BUFF_TIME_SKILL = preload("res://resources/skills/rune_buff_time.tres")
const AREA_TIME_SKILL = preload("res://resources/skills/rune_area_time.tres")

static func build_skill(runes: Array[Rune]) -> Skill:
    if runes.is_empty():
        return null
    var types: Array[int] = []
    for r in runes:
        types.append(r.rune_type)
    types.sort()
    var base: Skill = null
    match types:
        [Rune.RuneType.STRIKE]:
            base = STRIKE_SKILL
        [Rune.RuneType.BUFF]:
            base = BUFF_SKILL
        [Rune.RuneType.AREA]:
            base = AREA_SKILL
        [Rune.RuneType.TIME]:
            base = TIME_SKILL
        [Rune.RuneType.STRIKE, Rune.RuneType.BUFF]:
            base = STRIKE_BUFF_SKILL
        [Rune.RuneType.STRIKE, Rune.RuneType.AREA]:
            base = STRIKE_AREA_SKILL
        [Rune.RuneType.STRIKE, Rune.RuneType.TIME]:
            base = STRIKE_TIME_SKILL
        [Rune.RuneType.BUFF, Rune.RuneType.AREA]:
            base = BUFF_AREA_SKILL
        [Rune.RuneType.BUFF, Rune.RuneType.TIME]:
            base = BUFF_TIME_SKILL
        [Rune.RuneType.AREA, Rune.RuneType.TIME]:
            base = AREA_TIME_SKILL
        _:
            base = null
    if base == null:
        return null
    var affixes: Array[Affix] = []
    if types == [Rune.RuneType.BUFF, Rune.RuneType.TIME]:
        for r in runes:
            for a in r.affixes:
                if r.rune_type == Rune.RuneType.TIME:
                    var ok = true
                    for v in a.main_stat_bonuses.values():
                        if v < 0:
                            ok = false
                    for v in a.stat_bonuses.values():
                        if v < 0:
                            ok = false
                    if not ok:
                        continue
                affixes.append(a)
    else:
        for r in runes:
            affixes += r.affixes
    var skill = RuneSkill.new(base.duplicate(true), affixes)
    return skill
