class_name SkillIcon
extends TextureButton

# Displays a player's skill with cooldown, active state and mana cost feedback.
# Designed to be attached to a TextureButton in the editor. Child nodes
# referenced via the exported NodePaths are optional and allow custom visuals.

@export var player_path: NodePath
@export var slot_index: int = 0
@export var cooldown_progress_path: NodePath
@export var active_overlay_path: NodePath
@export var mana_overlay_path: NodePath

var _player
var _cooldown_progress: Range
var _active_overlay: CanvasItem
var _mana_overlay: CanvasItem

func _ready() -> void:
	if player_path != NodePath():
		_player = get_node(player_path)
	if cooldown_progress_path != NodePath():
		_cooldown_progress = get_node(cooldown_progress_path)
	if active_overlay_path != NodePath():
		_active_overlay = get_node(active_overlay_path)
	if mana_overlay_path != NodePath():
		_mana_overlay = get_node(mana_overlay_path)
	set_process(true)

func _process(_delta: float) -> void:
	if not _player:
		return
	var skill: Skill = _player.get_skill_slot(slot_index)
	texture_normal = skill.icon if skill else null
	if skill:
		tooltip_text = "%s\n%s" % [skill.name, skill.description]
	else:
		tooltip_text = ""
	var cooldown = _player.get_skill_cooldown_remaining(slot_index)
	if _cooldown_progress and skill:
		var denom = max(skill.cooldown, 0.001)
		_cooldown_progress.value = cooldown / denom * _cooldown_progress.max_value
		_cooldown_progress.visible = cooldown > 0.0
	if _active_overlay:
		_active_overlay.visible = _player.is_skill_active(slot_index)
	if _mana_overlay and skill:
		_mana_overlay.visible = _player.mana < skill.mana_cost
