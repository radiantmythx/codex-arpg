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
	var base_skill: Skill = base.duplicate(true)
	_apply_base_damage(base_skill, runes)
	var skill = RuneSkill.new(base_skill, affixes)
	return skill


static func _apply_base_damage(skill: Skill, runes: Array[Rune]) -> void:
	var rune_map: Dictionary = {}
	for r in runes:
		rune_map[r.rune_type] = r
	if skill is ComboSkill:
		for s in skill.skills:
			_apply_base_damage(s, runes)
		return
	if skill is MeleeSkill:
		var sr: Rune = rune_map.get(Rune.RuneType.STRIKE, null)
		if sr:
			skill.base_damage_low = sr.base_damage_low
			skill.base_damage_high = sr.base_damage_high
			skill.damage_type = sr.base_damage_type
		if not skill.tags.has("Melee"):
			skill.tags.append("Melee")
		if skill.on_hit_buff is DamageOverTimeBuff and rune_map.has(Rune.RuneType.TIME):
			var tr: Rune = rune_map[Rune.RuneType.TIME]
			skill.on_hit_buff.base_damage_low = tr.base_damage_low
			skill.on_hit_buff.base_damage_high = tr.base_damage_high
			skill.on_hit_buff.damage_type = tr.base_damage_type
	elif skill is BlastSkill:
		var ar: Rune = rune_map.get(Rune.RuneType.AREA, null)
		if ar:
			skill.base_damage_low = ar.base_damage_low
			skill.base_damage_high = ar.base_damage_high
			skill.damage_type = ar.base_damage_type
		elif rune_map.has(Rune.RuneType.TIME):
			var tr: Rune = rune_map[Rune.RuneType.TIME]
			skill.base_damage_low = tr.base_damage_low
			skill.base_damage_high = tr.base_damage_high
			skill.damage_type = tr.base_damage_type
		if not skill.tags.has("Spell"):
			skill.tags.append("Spell")
		if skill.on_hit_buff is DamageOverTimeBuff and rune_map.has(Rune.RuneType.TIME):
			var tr2: Rune = rune_map[Rune.RuneType.TIME]
			skill.on_hit_buff.base_damage_low = tr2.base_damage_low
			skill.on_hit_buff.base_damage_high = tr2.base_damage_high
			skill.on_hit_buff.damage_type = tr2.base_damage_type
	elif skill is ProjectileSkill:
		var tr3: Rune = rune_map.get(Rune.RuneType.TIME, null)
		if tr3:
			skill.base_damage_low = tr3.base_damage_low
			skill.base_damage_high = tr3.base_damage_high
			skill.damage_type = tr3.base_damage_type
		if not skill.tags.has("Spell"):
			skill.tags.append("Spell")
		if skill.on_hit_buff is DamageOverTimeBuff and tr3:
			skill.on_hit_buff.base_damage_low = tr3.base_damage_low
			skill.on_hit_buff.base_damage_high = tr3.base_damage_high
			skill.on_hit_buff.damage_type = tr3.base_damage_type
