extends CharacterBody3D

@export var move_speed: float = 5.0 # Base move speed before modifiers
@export var rotation_speed: float = 15.0
@export var base_attack_speed: float = 1.0
@export var main_skill: Skill = preload("res://resources/skills/holy_smite.tres")
@export var secondary_skill: Skill = preload("res://resources/skills/haste.tres")
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

# Base combat and attribute values.
@export var base_damage: float = 1.0
@export var base_defense: float = 0.0
@export var base_armor: float = 0.0
@export var base_evasion: float = 0.0
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

var _attack_timer: float = 0.0
var _attacking_timer: float = 0.0
var _secondary_cooldown: float = 0.0
var inventory := Inventory.new()
var _inventory_ui: InventoryUI
var _skills_ui: SkillsUI
var _camera: Camera3D
var _camera_offset: Vector3 = Vector3.ZERO ## Offset from player to camera.
var _inventory_open := false
var _skills_open := false
var _healthbar: Healthbar
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

var _anim_tree: AnimationTree
var _anim_state: AnimationNodeStateMachinePlayback
var _attack_progress: float = 0.0
var _attack_execute_time: float = 0.0
var _attack_cancel_time: float = 0.0
var _attack_performed: bool = false
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
	equipment.set_slots(["weapon", "offhand", "armor", "helmet"])
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
	rune_manager.set_slot_count(2)
	rune_manager.connect("skill_changed", Callable(self, "_on_rune_skill_changed"))

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
	if not _dialogue_ui:
			var canvas_layer := get_node_or_null("../CanvasLayer")
			if canvas_layer:
				_dialogue_ui = DialogueBox.new()
				canvas_layer.add_child(_dialogue_ui)

	add_to_group("player")

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

func _physics_process(delta: float) -> void:
				_process_inventory_input()
				_process_attack(delta)
				_process_movement(delta)
				_update_animation()
				_process_regen(delta)
				_update_target_hover()
				_process_npc_interact()
				_update_camera()

func _process_movement(delta: float) -> void:
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
                       input_dir.z -= 1
               if Input.is_action_pressed("move_back"):
                       input_dir.z += 1
               if Input.is_action_pressed("move_left"):
                       input_dir.x -= 1
               if Input.is_action_pressed("move_right"):
                       input_dir.x += 1
               input_dir = input_dir.normalized()
               _last_local_input = input_dir
               # Convert the local input into world space using the camera's
               # orientation.  The magnitude is preserved so only the movement
               # direction changes.
               var move_dir := input_dir
               var cam := get_viewport().get_camera_3d()
               if cam:
                       var cam_basis := cam.global_transform.basis
                       var cam_forward := -cam_basis.z
                       var cam_right := cam_basis.x
                       move_dir = (cam_forward * input_dir.z + cam_right * input_dir.x)
                       move_dir.y = 0.0
                       move_dir = move_dir.normalized()
               if move_dir != Vector3.ZERO:
                       _last_move_input = move_dir
               var look_dir = _get_click_direction()
               var target_rot = Transform3D().looking_at(look_dir, Vector3.UP).basis.get_euler().y
               if(_attacking_timer <= 0.0):
                       rotation.y = lerp_angle(rotation.y, target_rot, rotation_speed * delta)
               var speed = stats.get_move_speed()
               if _attacking_timer > 0.0:
                       speed *= _current_move_multiplier
               velocity.x = move_dir.x * speed
               velocity.z = move_dir.z * speed
		if Input.is_action_just_pressed("dodge") and _dodge_cooldown_timer <= 0.0 and not _is_dodging and _attacking_timer <= 0.0:
			_start_dodge()
	if _invincible_timer > 0.0:
		_invincible_timer -= delta
	move_and_slide()

func _process_attack(delta: float) -> void:
		if _is_dodging:
						return
		if _attack_timer > 0.0:
						_attack_timer -= delta
		if _secondary_cooldown > 0.0:
				_secondary_cooldown -= delta
		if _attacking_timer > 0.0:
				_attacking_timer -= delta
				_attack_progress += delta
				if not _attack_performed and _attack_progress >= _attack_execute_time:
						if main_skill:
								main_skill.perform(self)
						_attack_performed = true
				if _attack_cancel_time > 0.0 and _attack_progress >= _attack_cancel_time:
						_attacking_timer = 0.0
				if _attacking_timer <= 0.0 and _anim_state:
						_anim_state.travel("move")
		if Input.is_action_pressed("attack") and _attack_timer <= 0.0 and main_skill and _attacking_timer <= 0.0:
				if mana >= main_skill.mana_cost:
						_anim_state.travel("move") #reset anim state
						var speed = get_attack_speed(main_skill.tags)
						print("Attack speed is ", speed)
						_attack_timer = main_skill.cooldown / max(speed, 0.001)
						_attacking_timer = main_skill.duration / max(speed, 0.001)
						_attack_progress = 0.0
						_attack_execute_time = main_skill.attack_time / max(speed, 0.001)
						_attack_cancel_time = main_skill.cancel_time / max(speed, 0.001)
						_attack_performed = false
						_current_move_multiplier = main_skill.move_multiplier
						mana -= main_skill.mana_cost
						var look_dir = _get_click_direction()
						var target_rot = Transform3D().looking_at(look_dir, Vector3.UP).basis.get_euler().y
						rotation.y = target_rot
						if _anim_state and main_skill.animation_name != &"":
								#print(main_skill.animation_name)
								_anim_tree.set("parameters/%s/TimeScale/scale" % str(main_skill.animation_name), speed)
								# Reset animation time to start (0.0)
								#_anim_tree.set("parameters/%s/time" % str(main_skill.animation_name), 0.0)
								_anim_state.start(String(main_skill.animation_name), true)
						else:
								print("no anim for skill")
								main_skill.perform(self)
								_attack_performed = true
								_attacking_timer = 0.0
		if secondary_skill and Input.is_action_just_pressed("skill_1") and _secondary_cooldown <= 0.0:
				if mana >= secondary_skill.mana_cost:
						_secondary_cooldown = secondary_skill.cooldown
						mana -= secondary_skill.mana_cost
						secondary_skill.perform(self)

func _update_animation() -> void:
		if not _anim_tree or not _anim_state:
				return
		if _attacking_timer > 0.0 or _dodge_timer > 0.0:
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
		if _inventory_open:
				target.x += inventory_camera_shift
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
	if index == 0:
		main_skill = skill
	elif index == 1:
		secondary_skill = skill

func get_skill_slot(index: int) -> Skill:
		if rune_manager:
				return rune_manager.get_skill(index)
		return null

func get_skill_cooldown_remaining(index: int) -> float:
	match index:
		0:
			return max(_attack_timer, 0.0)
		1:
			return max(_secondary_cooldown, 0.0)
		_:
			return 0.0

func is_skill_active(index: int) -> bool:
	match index:
		0:
			return _attacking_timer > 0.0
		1:
			return false
		_:
			return false

func set_skill_slot(_index: int, _skill: Skill) -> void:
		# Skills are determined by rune combinations; manual assignment disabled.
		pass

## Equip slot callback. When a weapon is equipped, apply its default skill if provided.
func _on_equipment_slot_changed(slot: String, item: Item) -> void:
		if slot != "weapon":
				return
		if item is Weapon and item.default_skill:
				main_skill = item.default_skill

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
	if _inventory_open and _inventory_ui:
		_inventory_ui.pickup_to_cursor(item, amount)
	else:
		inventory.add_item(item, amount)

func take_damage(amount: float, damage_type: Stats.DamageType = Stats.DamageType.PHYSICAL) -> void:
	if _invincible_timer > 0.0:
			return
	if damage_type == Stats.DamageType.PHYSICAL:
		if randf() < stats.get_evasion() / 100.0:
				return
		amount = max(0.0, amount - stats.get_armor())
	var resist = stats.get_resistance(damage_type)
	amount = amount * (1.0 - resist / 100.0)
	amount = max(0.0, amount - stats.get_defense())
	if damage_type != Stats.DamageType.HOLY and damage_type != Stats.DamageType.UNHOLY and energy_shield > 0.0:
		var absorbed = min(energy_shield, amount)
		energy_shield -= absorbed
		amount -= absorbed
	_es_recharge_timer = stats.get_energy_shield_recharge_delay()
	health -= amount
	if _healthbar:
		_healthbar.set_health(health, max_health)
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
		if result and result.collider and (result.collider.is_in_group("enemy") or result.collider.is_in_group("npc")):
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
						if c.is_in_group("enemy") or c.is_in_group("npc"):
								target = c
								break
		if target != _hovered_target:
				if _hovered_target and _hovered_target.has_method("set_hovered"):
						_hovered_target.set_hovered(false)
				_hovered_target = target
				if _hovered_target and _hovered_target.has_method("set_hovered"):
						_hovered_target.set_hovered(true)
		_target_display.update_target(target)

func _process_npc_interact() -> void:
		## Handle left-click interactions with friendly NPCs.
		if not _hovered_target or not _hovered_target.is_in_group("npc"):
				return
		if not Input.is_action_just_pressed("interact"):
				return
		if global_transform.origin.distance_to(_hovered_target.global_transform.origin) > _hovered_target.interaction_range:
				return
		if _dialogue_ui and _camera:
				_dialogue_ui.start_conversation(_hovered_target, self, _camera)
