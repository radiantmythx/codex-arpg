extends CharacterBody3D

@export var move_speed: float = 5.0 # Base move speed before modifiers
@export var rotation_speed: float = 5.0
@export var main_skill: Skill = preload("res://resources/skills/fireball.tres")
@export var secondary_skill: Skill = preload("res://resources/skills/transcendent_fire.tres")
@export var inventory_ui_path: NodePath
@export var inventory_camera_path: NodePath
@export var inventory_camera_shift: float = 3.0

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
@export var base_max_health: float = 3.0
@export var base_max_mana: float = 50.0
@export var base_health_regen: float = 0.0
@export var base_mana_regen: float = 1.0

var _attack_timer: float = 0.0
var _attacking_timer: float = 0.0
var _secondary_cooldown: float = 0.0
var inventory := Inventory.new()
var _inventory_ui: InventoryUI
var _camera: Camera3D
var _camera_default_pos: Vector3
var _inventory_open := false
var _healthbar: Healthbar
var _current_move_multiplier: float = 1.0

var energy_shield: float = 0.0
var max_energy_shield: float = 0.0
var _es_recharge_timer: float = 0.0

var health: float = 3.0
var max_health: float = 3.0
var mana: float = 50.0
var max_mana:float = 50.0

var stats: Stats
var equipment: EquipmentManager

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

	equipment = EquipmentManager.new()
	equipment.stats = stats
	equipment.set_slots(["weapon", "armor"])
	add_child(equipment)

	add_child(inventory)
	if inventory_ui_path != NodePath():
		_inventory_ui = get_node(inventory_ui_path)
		if _inventory_ui:
			_inventory_ui.bind_inventory(inventory)
			_inventory_ui.bind_equipment(equipment)
	if inventory_camera_path != NodePath():
		_camera = get_node(inventory_camera_path)
		if _camera:
			_camera_default_pos = _camera.position
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
		_process_regen(delta)

func _process_movement(delta: float) -> void:
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

	if input_dir != Vector3.ZERO:
		var target_rot = Transform3D().looking_at(input_dir, Vector3.UP).basis.get_euler().y
		rotation.y = lerp_angle(rotation.y, target_rot, rotation_speed * delta)
		var speed = stats.get_move_speed()
		if _attacking_timer > 0.0:
				speed *= _current_move_multiplier
		velocity = input_dir * speed
	else:
		velocity = Vector3()
	move_and_slide()

func _process_attack(delta: float) -> void:
				if _attack_timer > 0.0:
								_attack_timer -= delta
				if _attacking_timer > 0.0:
								_attacking_timer -= delta
				if _secondary_cooldown > 0.0:
								_secondary_cooldown -= delta
				if Input.is_action_just_pressed("attack") and _attack_timer <= 0.0 and main_skill:
												if mana >= main_skill.mana_cost:
																				_attack_timer = main_skill.cooldown
																				_attacking_timer = main_skill.duration
																				_current_move_multiplier = main_skill.move_multiplier
																				mana -= main_skill.mana_cost
																				main_skill.perform(self)
				if secondary_skill and Input.is_action_just_pressed("skill_1") and _secondary_cooldown <= 0.0:
								if mana >= secondary_skill.mana_cost:
												_secondary_cooldown = secondary_skill.cooldown
												mana -= secondary_skill.mana_cost
												secondary_skill.perform(self)

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
	_shift_camera(true)

func close_inventory() -> void:
	_inventory_open = false
	if _inventory_ui:
		_inventory_ui.close()
	_shift_camera(false)

func _shift_camera(open: bool) -> void:
	if not _camera:
		return
	var target := _camera_default_pos
	if open:
		target.x += inventory_camera_shift
	var tween := create_tween()
	tween.tween_property(_camera, "position", target, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func add_item(item: Item, amount: int = 1) -> void:
	if _inventory_open and _inventory_ui:
		_inventory_ui.pickup_to_cursor(item, amount)
	else:
		inventory.add_item(item, amount)

func take_damage(amount: float, damage_type: Stats.DamageType = Stats.DamageType.PHYSICAL) -> void:
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
				mana = min(max_mana, mana + stats.get_mana_regen() * delta)
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
