extends CharacterBody3D

@export var move_speed: float = 5.0 # Base move speed before modifiers
@export var rotation_speed: float = 15.0
@export var base_attack_speed: float = 1.0

# Skills -------------------------------------------------------------------
# The legacy implementation exposed `main_skill` and `secondary_skill` fields
# and hard-coded the player to exactly two abilities.  The new system supports
# up to eight slots that are bound to input actions named "Skill1" through
# "Skill8" (with backwards compatibility for the old "attack" and
# "skill_#" actions).  We keep the exported properties so existing scenes and
# resources continue to load, but internally we mirror them into the generic
# `skill_slots` array once the skill system has been initialized.
var _skill_system_initialized := false
@export var debug_known_skills:Array[Skill] = []

@export var inventory_ui_path: NodePath
@export var inventory_camera_path: NodePath
@export var inventory_camera_shift: float = 3.0
@export var skills_ui_path: NodePath
@export var animation_tree_path: NodePath

# Skeleton containing the player's bones.  Equipment models are attached to
# this skeleton so they follow animations.
@export var skeleton_path: NodePath = NodePath("Armature/Skeleton3D")
## Optional hair model that will be attached to the head.  The hair is
## automatically hidden when equipped items request it (e.g. helmets with the
## `hide_hair` flag).
@export var hair_scene: PackedScene
@export var hair_bone: String = "mixamorig_Head"

# UI control that displays the hovered enemy's health bar.
@export var target_display_path: NodePath
@export var dialogue_ui_path: NodePath ## NodePath to the DialogueBox control.

@export var healthbar_node_path: NodePath
@export var health_orb_node_path: NodePath
@export var mana_orb_node_path: NodePath

# Base combat and attribute values.
@export var base_damage: float = 1.0
@export var base_defense: float = 0.0
@export var base_armor: float = 0.0
@export var base_evasion: float = 5.0 ## % chance to avoid damage entirely.
@export var base_block: float = 5.0 ## % chance to block after evasion fails.
@export var base_max_evasion: float = 75.0 ## Default evasion cap.
@export var base_max_block: float = 75.0 ## Default block cap.
@export var base_damage_reduction: float = 0.0 ## % reduction applied after resistances.
@export var base_max_energy_shield: float = 0.0
@export var base_energy_shield_regen: float = 0.0
@export var base_energy_shield_recharge_delay: float = 2.0
@export var base_body: int = 0
@export var base_mind: int = 0
@export var base_soul: int = 0
@export var base_luck: int = 0
@export var base_max_health: float = 50.0
@export var base_max_mana: float = 50.0
@export var base_health_regen: float = 0.0
@export var base_mana_regen: float = 1.0


const MAX_SKILL_SLOTS := 8
const SKILL_ACTIONS := ["Skill1", "Skill2", "Skill3", "Skill4", "Skill5", "Skill6", "Skill7", "Skill8"]
const LEGACY_SKILL_ACTIONS := ["attack", "skill_1", "skill_2", "skill_3", "skill_4", "skill_5", "skill_6", "skill_7", "skill_8"]

var skill_slots: Array[Skill] = []
var known_skills: Array[Skill] = []
var _skill_cooldowns: Array[float] = []
var _active_skill_index: int = -1
var _active_skill_timer: float = 0.0
var _active_skill_progress: float = 0.0
var _active_skill_execute_time: float = 0.0
var _active_skill_cancel_time: float = 0.0
var _active_skill_performed: bool = false
var inventory := Inventory.new()
var _inventory_ui: InventoryUI
var _skills_ui: SkillsUI
var _camera: Camera3D
var _camera_offset: Vector3 = Vector3.ZERO ## Offset from player to camera.
var _inventory_open := false
var _skills_open := false
var _healthbar: Healthbar
var _health_orb: HealthOrb
var _mana_orb: HealthOrb
var _target_display: TargetDisplay
var _dialogue_ui: DialogueBox
var _hovered_target: Node
var _current_move_multiplier: float = 1.0
var buff_manager: BuffManager
var reserved_mana: float = 0.0

@export var dodge_speed: float = 10.0 # Movement speed while rolling
@export var dodge_duration: float = 0.4 # Seconds the roll lasts
@export var dodge_cooldown: float = 1.0 # Delay before another roll can start
@export var dodge_invincibility_time: float = 0.3 # Time the player ignores damage at the start of a roll
var _dodge_cooldown_timer: float = 0.0
var _dodge_timer: float = 0.0
var _dodge_direction: Vector3 = Vector3.ZERO
var _invincible_timer: float = 0.0
var _is_dodging: bool = false
var _dodge_exceptions: Array = []
var _last_move_input: Vector3 = Vector3.FORWARD

# --- Movement skill state ---
# These variables track the transient state when a MovementSkill is active.
var _movement_skill_active: bool = false
var _movement_skill_velocity: Vector3 = Vector3.ZERO
var _movement_skill_timer: float = 0.0
var _movement_skill_stop_on_collision: bool = false
var _movement_skill_damage_radius: float = 0.0
var _movement_skill_dmg_map: Dictionary = {}
var _movement_skill_on_arrival_effect: PackedScene
var _movement_skill_active_effect: Node
var _movement_skill_phase: bool = false
var _movement_skill_restore_layer: int = 0
var _movement_skill_restore_mask: int = 0

var _anim_tree: AnimationTree
var _anim_state: AnimationNodeStateMachinePlayback
var _last_local_input: Vector3 = Vector3.ZERO

var energy_shield: float = 0.0
var max_energy_shield: float = 0.0
var _es_recharge_timer: float = 0.0

var health: float = 3.0
var max_health: float = 3.0
var mana: float = 50.0
var max_mana:float = 50.0

var stats: Stats
var equipment: EquipmentManager
var rune_manager: RuneManager
var _equip_visuals: EquipmentVisualManager

func _ready() -> void:
	stats = Stats.new()
	stats.base_move_speed = move_speed
	stats.base_damage[Stats.DamageType.PHYSICAL] = base_damage
	stats.base_defense = base_defense
	stats.base_armor = base_armor
	stats.base_evasion = base_evasion
	stats.base_block = base_block
	stats.base_max_evasion = base_max_evasion
	stats.base_max_block = base_max_block
	stats.base_damage_reduction = base_damage_reduction
	stats.base_max_energy_shield = base_max_energy_shield
	stats.base_energy_shield_regen = base_energy_shield_regen
	stats.base_energy_shield_recharge_delay = base_energy_shield_recharge_delay
	stats.base_main[Stats.MainStat.BODY] = base_body
	stats.base_main[Stats.MainStat.MIND] = base_mind
	stats.base_main[Stats.MainStat.SOUL] = base_soul
	stats.base_main[Stats.MainStat.LUCK] = base_luck
	stats.base_max_health = base_max_health
	stats.base_max_mana = base_max_mana
	stats.base_health_regen = base_health_regen
	stats.base_mana_regen = base_mana_regen
	stats.base_attack_speed = base_attack_speed

	equipment = EquipmentManager.new()
	equipment.stats = stats
	# Create equipment slots.  Rings use the same "ring" slot type but
	# appear twice so the player can wear one on each hand.
	# `EquipmentManager` will treat duplicate entries as separate slots.
	equipment.set_slots(["weapon", "offhand", "body", "legs", "quiver", "cloak", "amulet", "helmet", "ring", "ring", "boots"])
	equipment.connect("slot_changed", Callable(self, "_on_equipment_slot_changed"))
	add_child(equipment)

	# Visual manager displays meshes for equipped items.
	var skeleton: Skeleton3D = get_node_or_null(skeleton_path)
	_equip_visuals = EquipmentVisualManager.new()
	_equip_visuals.skeleton = skeleton
	_equip_visuals.equipment = equipment
	_equip_visuals.hair_scene = hair_scene
	add_child(_equip_visuals)

	rune_manager = RuneManager.new()
	add_child(rune_manager)
	rune_manager.set_slot_count(MAX_SKILL_SLOTS)
	rune_manager.connect("skill_changed", Callable(self, "_on_rune_skill_changed"))

	_initialize_skill_system()

	add_child(inventory)
	buff_manager = BuffManager.new()
	buff_manager.stats = stats
	add_child(buff_manager)
	if animation_tree_path != NodePath():
			_anim_tree = get_node_or_null(animation_tree_path)
			if _anim_tree:
					_anim_tree.active = true
					_anim_state = _anim_tree.get("parameters/playback")
	if inventory_ui_path != NodePath():
		_inventory_ui = get_node(inventory_ui_path)
		if _inventory_ui:
				_inventory_ui.bind_inventory(inventory)
				_inventory_ui.bind_equipment(equipment)
				_inventory_ui.bind_rune_manager(rune_manager)
				_inventory_ui.bind_stats(stats)
		if inventory_camera_path != NodePath():
			_camera = get_node(inventory_camera_path)
			if _camera:
					_camera_offset = _camera.global_position - global_position
			if healthbar_node_path != NodePath():
							_healthbar = get_node(healthbar_node_path)
							max_health = int(stats.get_max_health())
							health = max_health
			max_mana = stats.get_max_mana()
			mana = max_mana
			max_energy_shield = stats.get_max_energy_shield()
			energy_shield = max_energy_shield
			if _healthbar:
					_healthbar.set_health(health, max_health)
					_healthbar.set_mana(mana, max_mana)
		if skills_ui_path != NodePath():
				_skills_ui = get_node(skills_ui_path)
				_skills_ui.bind_player(self)

	if target_display_path != NodePath():
					_target_display = get_node_or_null(target_display_path)
	if dialogue_ui_path != NodePath():
					_dialogue_ui = get_node_or_null(dialogue_ui_path)
	if health_orb_node_path != NodePath():
		_health_orb = get_node_or_null(health_orb_node_path)
	if mana_orb_node_path != NodePath():
		_mana_orb = get_node_or_null(mana_orb_node_path)
	if not _dialogue_ui:
			var canvas_layer := get_node_or_null("../CanvasLayer")
			if canvas_layer:
				_dialogue_ui = DialogueBox.new()
				canvas_layer.add_child(_dialogue_ui)

	add_to_group("player")

## Prepare arrays and defaults for the new multi-slot skill system.  This is
## called once during `_ready` after dependent nodes (such as the rune manager)
## are created.
func _initialize_skill_system() -> void:
		skill_slots.resize(MAX_SKILL_SLOTS)
		_skill_cooldowns.resize(MAX_SKILL_SLOTS)
		for i in range(MAX_SKILL_SLOTS):
				skill_slots[i] = null
				_skill_cooldowns[i] = 0.0
		_skill_system_initialized = true
		_assign_skill_slot(0, debug_known_skills[0], false)
		_assign_skill_slot(1, debug_known_skills[1], false)
		_assign_skill_slot(2, debug_known_skills[2], false)
		_assign_skill_slot(3, debug_known_skills[3], false)
#		_assign_skill_slot(4, debug_known_skills[4], false)
#		_assign_skill_slot(5, debug_known_skills[5], false)
#		_assign_skill_slot(6, debug_known_skills[6], false)
#		_assign_skill_slot(7, debug_known_skills[7], false)
		_rebuild_known_skills()

func _get_click_direction() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return -global_transform.basis.z
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	var plane_y := global_transform.origin.y
	if abs(ray_dir.y) <= 0.0001:
		return -global_transform.basis.z
	var distance := (plane_y - ray_origin.y) / ray_dir.y
	var target := ray_origin + ray_dir * distance
	return (target - global_transform.origin).normalized()

# Returns the world-space position on the horizontal plane at the mouse cursor.
# This mirrors `_get_click_direction` but provides the actual target location
# which is required by movement skills to know where to travel.
# World-space position on horizontal plane at mouse cursor.
func _get_click_position() -> Vector3:
		var cam := get_viewport().get_camera_3d()
		if cam == null:
				return global_transform.origin

		# IMPORTANT: use the camera's viewport in case it's a SubViewport.
		var vp := cam.get_viewport()
		var mouse := vp.get_mouse_position()

		var ray_origin := cam.project_ray_origin(mouse)
		var ray_dir := cam.project_ray_normal(mouse)

		# If ray is (almost) parallel to the horizontal plane, bail.
		if abs(ray_dir.y) <= 0.0001:
				return global_transform.origin

		var plane_y := global_transform.origin.y

		# Calculate intersection of the mouse ray with a horizontal plane
		# at the player's height.  This mirrors `_get_click_direction` but
		# returns the position instead of a direction vector.
		var distance := (plane_y - ray_origin.y) / ray_dir.y
		if distance < 0.0:
				return global_transform.origin

		return ray_origin + ray_dir * distance

func _physics_process(delta: float) -> void:
				_process_inventory_input()
				_process_attack(delta)
				_process_movement(delta)
				_update_animation()
				_process_regen(delta)
				_update_target_hover()
				_process_interactables()
				_update_camera()

func _process_movement(delta: float) -> void:
		# If a movement skill is active we let it drive all motion for the
		# duration and bypass normal input handling.
	if _movement_skill_active:
		_movement_skill_timer -= delta
		var motion := _movement_skill_velocity * delta
		if _movement_skill_stop_on_collision and not _movement_skill_phase:
				var collision := move_and_collide(motion)
				if collision:
						_end_movement_skill()
						return
		else:
				translate(motion)
		if _movement_skill_damage_radius > 0.0:
				_movement_skill_apply_damage()
		if _movement_skill_timer <= 0.0:
				_end_movement_skill()
		return
	if _dodge_cooldown_timer > 0.0:
			_dodge_cooldown_timer -= delta
	if _dodge_timer > 0.0:
			_dodge_timer -= delta
			velocity = _dodge_direction * dodge_speed
			if _dodge_timer <= 0.0:
				_is_dodging = false
				_remove_dodge_exceptions()
				if _anim_state:
					_anim_state.travel("move")
	else:
		var input_dir = Vector3.ZERO
		if Input.is_action_pressed("move_forward"):
				input_dir.z += 1
		if Input.is_action_pressed("move_back"):
				input_dir.z -= 1
		if Input.is_action_pressed("move_left"):
				input_dir.x -= 1
		if Input.is_action_pressed("move_right"):
				input_dir.x += 1
		input_dir = input_dir.normalized()
		_last_local_input = input_dir
		   # Convert the local input into world space using the camera's
		   # orientation.  The magnitude is preserved so only the movement
		   # direction changes.
		var move_dir = input_dir
		var cam := get_viewport().get_camera_3d()
		if cam:
				var cam_basis := cam.global_transform.basis
				var cam_forward := -cam_basis.z
				var cam_right := cam_basis.x
				move_dir = (cam_forward * input_dir.z + cam_right * input_dir.x)
				move_dir.y = 0.0
				move_dir = move_dir.normalized()
				#move_dir.z = -move_dir.z
		if move_dir != Vector3.ZERO:
			_last_move_input = move_dir
		var look_dir = _get_click_direction()
		var target_rot = Transform3D().looking_at(look_dir, Vector3.UP).basis.get_euler().y
		if(_active_skill_timer <= 0.0):
						rotation.y = lerp_angle(rotation.y, target_rot, rotation_speed * delta)
		var speed = stats.get_move_speed()
		if _active_skill_timer > 0.0:
						speed *= _current_move_multiplier
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed
		if Input.is_action_just_pressed("dodge") and _dodge_cooldown_timer <= 0.0 and not _is_dodging and _active_skill_timer <= 0.0:
				_start_dodge()
	if _invincible_timer > 0.0:
		_invincible_timer -= delta
	move_and_slide()

func _process_attack(delta: float) -> void:
		# Cooldowns tick continuously so the UI remains in sync even while
		# the player is dodging or performing other actions.
		for i in range(_skill_cooldowns.size()):
				if _skill_cooldowns[i] > 0.0:
						_skill_cooldowns[i] = max(_skill_cooldowns[i] - delta, 0.0)

		var skill_active := _active_skill_index != -1
		if skill_active:
				_active_skill_timer -= delta
				_active_skill_progress += delta
				var active_skill := _get_active_skill()
				if active_skill:
						if not _active_skill_performed and _active_skill_progress >= _active_skill_execute_time:
								active_skill.perform(self)
								_active_skill_performed = true
						if _active_skill_cancel_time > 0.0 and _active_skill_progress >= _active_skill_cancel_time:
								_active_skill_timer = 0.0
				if not active_skill or _active_skill_timer <= 0.0:
						_end_active_skill()
						skill_active = false

		if _movement_skill_active or _is_dodging:
				return
		if skill_active:
				return

		for i in range(min(skill_slots.size(), MAX_SKILL_SLOTS)):
				var skill: Skill = skill_slots[i]
				if not skill:
						continue
				if i >= _skill_cooldowns.size():
						continue
				if _skill_cooldowns[i] > 0.0:
						continue
				if mana < skill.mana_cost:
						continue
				if _is_skill_input_triggered(i):
						_activate_skill(i, skill)
						break

## Retrieve the currently active skill from the slot array.
func _get_active_skill() -> Skill:
		if _active_skill_index < 0 or _active_skill_index >= skill_slots.size():
				return null
		return skill_slots[_active_skill_index]

## Check if the input mapped to the given slot was triggered this frame.
func _is_skill_input_triggered(index: int) -> bool:
		var allow_hold := index == 0
		var action_names: Array[String] = []
		if index < SKILL_ACTIONS.size():
				action_names.append(SKILL_ACTIONS[index])
		if index < LEGACY_SKILL_ACTIONS.size():
				action_names.append(LEGACY_SKILL_ACTIONS[index])
		for action_name in action_names:
				if _is_action_triggered(action_name, allow_hold):
						return true
		return false

## Wrapper that guards against querying actions that are not defined in the
## InputMap.  Godot prints errors otherwise, so the explicit check keeps the
## logs tidy while still supporting custom control schemes.
func _is_action_triggered(action_name: String, allow_hold: bool) -> bool:
		if action_name.is_empty():
				return false
		if not InputMap.has_action(action_name):
				return false
		if allow_hold:
				return Input.is_action_pressed(action_name)
		return Input.is_action_just_pressed(action_name)

## Start casting/performing the selected skill.  Cooldowns, timers, movement
## multipliers and animation playback are all set up here so the main process
## loop only needs to advance timers afterwards.
func _activate_skill(index: int, skill: Skill) -> void:
		if skill == null:
				return
		var speed := get_attack_speed(skill.tags)
		var scaled_speed = max(speed, 0.001)
		if index < _skill_cooldowns.size():
				_skill_cooldowns[index] = skill.cooldown / scaled_speed
		_active_skill_index = index
		_active_skill_timer = skill.duration / scaled_speed
		_active_skill_progress = 0.0
		_active_skill_execute_time = skill.attack_time / scaled_speed
		_active_skill_cancel_time = skill.cancel_time / scaled_speed
		_active_skill_performed = false
		_current_move_multiplier = skill.move_multiplier
		mana -= skill.mana_cost
		_update_mana_indicators()

		var look_dir := _get_click_direction()
		var target_rot := Transform3D().looking_at(look_dir, Vector3.UP).basis.get_euler().y
		rotation.y = target_rot

		if _anim_state and skill.animation_name != &"":
				_anim_tree.set("parameters/%s/TimeScale/scale" % str(skill.animation_name), speed)
				_anim_state.start(String(skill.animation_name), true)
		else:
				skill.perform(self)
				_active_skill_performed = true
				_end_active_skill()

## Reset all state associated with the active skill once its duration or
## animation finishes.
func _end_active_skill() -> void:
		_active_skill_index = -1
		_active_skill_timer = 0.0
		_active_skill_progress = 0.0
		_active_skill_execute_time = 0.0
		_active_skill_cancel_time = 0.0
		_active_skill_performed = false
		_current_move_multiplier = 1.0
		if _anim_state:
				_anim_state.travel("move")

## Update every UI element that displays mana so they stay in sync when skills
## consume the resource.
func _update_mana_indicators() -> void:
		if _healthbar:
				_healthbar.set_mana(mana, max_mana)
		if _mana_orb:
				_mana_orb.update_health(mana, max_mana)

func _update_animation() -> void:
				if not _anim_tree or not _anim_state:
								return
				if _active_skill_index != -1 or _dodge_timer > 0.0:
								return
				if _last_local_input != Vector3.ZERO:
								_anim_state.travel("move")
								var world_vel = Vector3(velocity.x, 0, velocity.z)
								var basis = global_transform.basis.orthonormalized()
								var right = basis.x
								var forward = -basis.z
								var local_x = world_vel.dot(right)
								var local_y = world_vel.dot(forward)
								_anim_tree.set("parameters/move/blend_position", Vector2(local_x, local_y))
				else:
								_anim_state.travel("move")
								_anim_tree.set("parameters/move/blend_position", Vector2.ZERO)

func _process_inventory_input() -> void:
	if Input.is_action_just_pressed("toggle_inventory"):
		if _inventory_open:
			close_inventory()
		else:
			open_inventory()

func open_inventory() -> void:
		_inventory_open = true
		if _inventory_ui:
				_inventory_ui.open()

func close_inventory() -> void:
		_inventory_open = false
		if _inventory_ui:
				_inventory_ui.close()
	
func _process_skills_input() -> void:
		if Input.is_action_just_pressed("toggle_skills_inv"):
				if _skills_open:
						close_skills()
				else:
						open_skills()

## Update the main camera so it smoothly follows the player. The camera
## maintains the initial offset from the player and shifts to the side when the
## inventory is open.
func _update_camera() -> void:
		if not _camera:
				return
		var target := global_position + _camera_offset
		#if _inventory_open:
		#		target.x += inventory_camera_shift
		_camera.global_position = _camera.global_position.lerp(target, 0.1)

func close_skills() -> void:
	_skills_open = false
	if _skills_ui:
		_skills_ui.close()

func open_skills() -> void:
	_skills_open = true
	if _skills_ui:
		_skills_ui.close()

func add_buff(buff: Buff) -> void:
	if buff_manager:
		buff_manager.apply_buff(buff)

func remove_buff(buff: Buff) -> void:
	if buff_manager:
		buff_manager.remove_buff(buff)

func _on_rune_skill_changed(index: int, skill: Skill) -> void:
		set_skill_slot(index, skill)

func get_skill_slot(index: int) -> Skill:
		if index < 0 or index >= skill_slots.size():
				return null
		return skill_slots[index]

func get_skill_cooldown_remaining(index: int) -> float:
		if index < 0 or index >= _skill_cooldowns.size():
				return 0.0
		return max(_skill_cooldowns[index], 0.0)

func is_skill_active(index: int) -> bool:
		return _active_skill_index == index

func set_skill_slot(index: int, skill: Skill) -> void:
		_assign_skill_slot(index, skill)
		_rebuild_known_skills()

## Internal helper used by the exported setters, rune manager callbacks and the
## UI to keep the slot array and exported properties in sync.
func _assign_skill_slot(index: int, skill: Skill, update_exports: bool = true) -> void:
		if index < 0 or index >= MAX_SKILL_SLOTS:
				return
		if skill_slots.size() < MAX_SKILL_SLOTS:
				skill_slots.resize(MAX_SKILL_SLOTS)
		if _skill_cooldowns.size() < MAX_SKILL_SLOTS:
				_skill_cooldowns.resize(MAX_SKILL_SLOTS)
		skill_slots[index] = skill
		_skill_cooldowns[index] = 0.0
		if update_exports:
				match index:
						0:
								debug_known_skills[0] = skill
						1:
								debug_known_skills[1] = skill
		if _active_skill_index == index:
				_end_active_skill()

## Refresh the list presented in the skills UI.  Only unique, non-null skills
## are tracked to avoid duplicates when multiple slots reference the same
## ability.
func _rebuild_known_skills() -> void:
		known_skills.clear()
		for skill in skill_slots:
				if skill and not known_skills.has(skill):
						known_skills.append(skill)

## Equip slot callback. When a weapon is equipped, apply its default skill if provided.
func _on_equipment_slot_changed(slot: String, index: int, item: Item) -> void:
				# Only react when the primary weapon slot changes.
				if slot != "weapon":
								return
				if item is Weapon and item.default_skill:
												set_skill_slot(0, item.default_skill)

## Returns a dictionary of base damage contributed by the equipped weapon for
## skills with the given tags.
func get_base_damage_dict(tags: Array[String] = []) -> Dictionary:
		var dict: Dictionary = {}
		var weapon: Item = equipment.get_item("weapon") if equipment else null
		if weapon is Weapon:
				var use := false
				match weapon.weapon_type:
						Weapon.WeaponType.MELEE:
								use = tags.has("melee")
						Weapon.WeaponType.PROJECTILE:
								use = tags.has("projectile")
						Weapon.WeaponType.SPELL:
								use = tags.has("spell")
				if use:
						dict[weapon.damage_type] = Vector2(weapon.base_damage_low, weapon.base_damage_high)
		return dict

## Calculates attack speed for a skill, factoring in weapon speed for matching tags.
func get_attack_speed(tags: Array[String] = []) -> float:
		var speed = stats.get_attack_speed_tagged(tags)
		var weapon: Item = equipment.get_item("weapon") if equipment else null
		if weapon is Weapon:
				match weapon.weapon_type:
						Weapon.WeaponType.MELEE:
								if tags.has("melee"):
										speed *= weapon.speed
						Weapon.WeaponType.PROJECTILE:
								if tags.has("projectile"):
										speed *= weapon.speed
						Weapon.WeaponType.SPELL:
								if tags.has("spell"):
										speed *= weapon.speed
		return speed

func add_item(item: Item, amount: int = 1) -> void:
		# When picking up equipment we duplicate the resource so currency
		# crafting only affects this instance. Stackable items like currency
		# keep their original resource so they can merge in the inventory.
		var inst := item
		if inst and inst.max_stack <= 1:
				inst = inst.duplicate(true)
		if _inventory_open and _inventory_ui:
				_inventory_ui.pickup_to_cursor(inst, amount)
		else:
				inventory.add_item(inst, amount)

func take_damage(amount: float, damage_type: Stats.DamageType = Stats.DamageType.PHYSICAL) -> void:
	if _invincible_timer > 0.0:
					return
	if randf() * 100.0 < stats.get_evasion():
			return
	if randf() * 100.0 < stats.get_block():
			return
	if damage_type == Stats.DamageType.PHYSICAL:
			amount = max(0.0, amount - stats.get_armor())
	var resist = stats.get_resistance(damage_type)
	amount = amount * (1.0 - resist / 100.0)
	amount = amount * (1.0 - stats.get_damage_reduction() / 100.0)
	amount = max(0.0, amount - stats.get_defense())
	if damage_type != Stats.DamageType.HOLY and damage_type != Stats.DamageType.UNHOLY and energy_shield > 0.0:
			var absorbed = min(energy_shield, amount)
			energy_shield -= absorbed
			amount -= absorbed
	_es_recharge_timer = stats.get_energy_shield_recharge_delay()
	health -= amount
	if _healthbar:
		_healthbar.set_health(health, max_health)
	if _health_orb:
		_health_orb.update_health(health, max_health)
	if health <= 0:
		die()

func _process_regen(delta: float) -> void:
	max_health = int(stats.get_max_health())
	health = min(max_health, health + stats.get_health_regen() * delta)
	max_mana = stats.get_max_mana()
	var max_available = max_mana - reserved_mana
	mana = min(max_available, mana + stats.get_mana_regen() * delta)
	max_energy_shield = stats.get_max_energy_shield()
	if energy_shield < max_energy_shield:
		if _es_recharge_timer > 0.0:
			_es_recharge_timer -= delta
		else:
			energy_shield = min(max_energy_shield, energy_shield + stats.get_energy_shield_regen() * delta)
	if _healthbar:
		_healthbar.set_health(health, max_health)
		_healthbar.set_mana(mana, max_mana)
	if _health_orb:
		_health_orb.update_health(health, max_health)
	if _mana_orb:
		_mana_orb.update_health(mana, max_mana)

func die():
				queue_free()

## Begin a dodge roll using the last movement direction.
func _start_dodge() -> void:
		_is_dodging = true
		_dodge_timer = dodge_duration
		_dodge_cooldown_timer = dodge_cooldown
		_invincible_timer = dodge_invincibility_time
			   # Use the last camera-relative movement direction so the roll
			   # mirrors the player's recent movement.  If no movement was
			   # recorded, roll forward based on the current facing direction.
		var dir := _last_move_input
		if dir == Vector3.ZERO:
						dir = -global_transform.basis.z
		_dodge_direction = dir.normalized()
		_dodge_direction.y = 0.0
		var target_y := Basis.looking_at(_dodge_direction, Vector3.UP).get_euler().y
		rotation.y = target_y

		_add_dodge_exceptions()
		if _anim_state:
				_anim_state.travel("roll")

## Ignore collisions with enemies during the roll.
func _add_dodge_exceptions() -> void:
		_dodge_exceptions.clear()
		for e in get_tree().get_nodes_in_group("enemy"):
				if e is CollisionObject3D:
						add_collision_exception_with(e)
						_dodge_exceptions.append(e)

## Restore enemy collisions after rolling.
func _remove_dodge_exceptions() -> void:
				for e in _dodge_exceptions:
								if is_instance_valid(e):
												remove_collision_exception_with(e)
				_dodge_exceptions.clear()

# --- Movement skill helpers ---
# Called by MovementSkill.perform to initialise movement state.
func start_movement_skill(skill: MovementSkill, direction: Vector3, distance: float, dmg_map: Dictionary) -> void:
				_movement_skill_active = true
				var speed := stats.get_move_speed() * skill.move_multiplier
				_movement_skill_velocity = direction * speed
				_movement_skill_timer = distance / max(speed, 0.001)
				_movement_skill_stop_on_collision = skill.stop_on_collision
				_movement_skill_damage_radius = skill.damage_radius
				_movement_skill_dmg_map = dmg_map
				_movement_skill_on_arrival_effect = skill.on_arrival_effect
				if skill.phase_through:
								_movement_skill_phase = true
								_movement_skill_restore_layer = collision_layer
								_movement_skill_restore_mask = collision_mask
								collision_layer = 0
								collision_mask = 0
				if skill.on_cast_effect:
								var cast_eff = skill.on_cast_effect.instantiate()
								cast_eff.global_transform.origin = global_transform.origin
								get_parent().add_child(cast_eff)
				if skill.active_effect:
								_movement_skill_active_effect = skill.active_effect.instantiate()
								add_child(_movement_skill_active_effect)

func _end_movement_skill() -> void:
				_movement_skill_active = false
				_movement_skill_timer = 0.0
				velocity = Vector3.ZERO
				if _movement_skill_phase:
								collision_layer = _movement_skill_restore_layer
								collision_mask = _movement_skill_restore_mask
								_movement_skill_phase = false
				if _movement_skill_active_effect:
								_movement_skill_active_effect.queue_free()
								_movement_skill_active_effect = null
				if _movement_skill_on_arrival_effect:
								var eff = _movement_skill_on_arrival_effect.instantiate()
								eff.global_transform.origin = global_transform.origin
								get_parent().add_child(eff)
								_movement_skill_on_arrival_effect = null

# Apply damage around the player while the movement skill is active.
func _movement_skill_apply_damage() -> void:
				var shape := SphereShape3D.new()
				shape.radius = _movement_skill_damage_radius
				var params := PhysicsShapeQueryParameters3D.new()
				params.shape = shape
				params.transform = Transform3D(Basis(), global_transform.origin)
				params.collide_with_bodies = true
				var bodies := get_world_3d().direct_space_state.intersect_shape(params, 32)
				for result in bodies:
								var body = result.get("collider")
								if body and body.has_method("take_damage") and body.is_in_group("enemy"):
												for dt in _movement_skill_dmg_map.keys():
																var dmg = _movement_skill_dmg_map[dt]
																if dmg > 0:
																				body.take_damage(dmg, dt)

func _update_target_hover() -> void:
		"""Cast a ray from the camera to the mouse and update the target display."""
		if not _target_display:
				return
		var camera := get_viewport().get_camera_3d()
		if camera == null:
				_target_display.update_target(null)
				return
		var mouse_pos := get_viewport().get_mouse_position()
		var origin := camera.project_ray_origin(mouse_pos)
		var dir := camera.project_ray_normal(mouse_pos)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 1000)
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		var target: Node = null
		if result and result.collider and (result.collider.is_in_group("enemy") or result.collider.is_in_group("npc") or result.collider.is_in_group("interactable")):
				target = result.collider
		elif result:
				# If the ray hit something else, check a small sphere around the point
				# of impact so near misses still select the target.
				var sphere := SphereShape3D.new()
				sphere.radius = 1.0
				var shape_query := PhysicsShapeQueryParameters3D.new()
				shape_query.shape = sphere
				shape_query.transform = Transform3D(Basis(), result.position)
				var hits := get_world_3d().direct_space_state.intersect_shape(shape_query)
				for h in hits:
								var c = h.collider
								if c.is_in_group("enemy") or c.is_in_group("npc") or c.is_in_group("interactable"):
												target = c
												break
		if target != _hovered_target:
						if _hovered_target and _hovered_target.has_method("set_hovered"):
										_hovered_target.set_hovered(false)
						_hovered_target = target
						if _hovered_target and _hovered_target.has_method("set_hovered"):
										_hovered_target.set_hovered(true)
		if target and (target.is_in_group("enemy") or target.is_in_group("npc")):
						_target_display.update_target(target)
		else:
						_target_display.update_target(null)

func _process_interactables() -> void:
				## Handle left-click interactions with NPCs and other interactables.
				if not _hovered_target:
								return
				if not Input.is_action_just_pressed("interact"):
								return
				if (_hovered_target.is_in_group("npc") or _hovered_target.is_in_group("interactable")) and _hovered_target.global_transform.origin.distance_to(_hovered_target.global_transform.origin) > _hovered_target.interaction_range:
								return
				if _hovered_target.is_in_group("npc"):
								if _dialogue_ui and _camera:
												_dialogue_ui.start_conversation(_hovered_target, self, _camera)
				elif _hovered_target.is_in_group("interactable"):
								if _inventory_open:
									close_inventory()
								if _hovered_target.has_method("interact"):
												_hovered_target.interact(self)
