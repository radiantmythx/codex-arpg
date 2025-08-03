class_name RuneManager
extends Node

signal slot_changed(slot_index: int, rune_index: int, rune: Rune)
signal skill_changed(slot_index: int, skill: Skill)

const RUNES_PER_SLOT := 2

var rune_slots: Array = [] # Array[Array[Rune]]
var skills: Array[Skill] = []

func set_slot_count(count: int) -> void:
    rune_slots.resize(count)
    skills.resize(count)
    for i in range(count):
        var arr: Array[Rune] = []
        arr.resize(RUNES_PER_SLOT)
        rune_slots[i] = arr
        skills[i] = null

func equip_rune(slot_index: int, rune_index: int, rune: Rune) -> Rune:
    var slot: Array = rune_slots[slot_index]
    var old: Rune = slot[rune_index]
    slot[rune_index] = rune
    _rebuild_skill(slot_index)
    emit_signal("slot_changed", slot_index, rune_index, rune)
    return old

func unequip_rune(slot_index: int, rune_index: int) -> Rune:
    var slot: Array = rune_slots[slot_index]
    var old: Rune = slot[rune_index]
    slot[rune_index] = null
    _rebuild_skill(slot_index)
    emit_signal("slot_changed", slot_index, rune_index, null)
    return old

func get_rune(slot_index: int, rune_index: int) -> Rune:
    return rune_slots[slot_index][rune_index]

func get_skill(slot_index: int) -> Skill:
    return skills[slot_index]

func _rebuild_skill(slot_index: int) -> void:
    var runes: Array[Rune] = []
    for r in rune_slots[slot_index]:
        if r:
            runes.append(r)
    var skill: Skill = RuneSkillFactory.build_skill(runes)
    skills[slot_index] = skill
    emit_signal("skill_changed", slot_index, skill)
