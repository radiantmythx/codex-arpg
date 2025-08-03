extends CharacterBody3D

@export var max_health: float = 3.0
@export var move_speed: float = 2.0
@export var wander_speed: float = 1.0
@export var wander_change_interval: float = 2.0
@export var detection_range: float = 8.0
@export var attack_range: float = 1.5
@export var main_skill: Skill = preload("res://resources/skills/basic_melee_attack.tres")
@export var healthbar_node_path: NodePath
@export var base_armor: float = 0.0
@export var base_evasion: float = 0.0
@export var base_max_energy_shield: float = 0.0
@export var base_energy_shield_regen: float = 0.0
@export var base_energy_shield_recharge_delay: float = 2.0
@export var base_damage: float = 1.0

## Drop table is an array of dictionaries like:
## {"item": Item, "chance": 0.5, "amount": 1}
@export var drop_table: Array = []

var current_health: float
var energy_shield: float = 0.0
var max_energy_shield: float = 0.0
var _es_recharge_timer: float = 0.0

signal died

var _player: Node3D
var _wander_timer: float = 0.0
var _current_dir: Vector3 = Vector3.ZERO
var _attack_timer: float = 0.0
var _mesh: MeshInstance3D
var _original_material: Material
var _healthbar: Healthbar
var stats: Stats
var buff_manager: BuffManager

func _ready() -> void:
		randomize()
		add_to_group("enemy")
		stats = Stats.new()
		stats.base_max_health = max_health
		stats.base_damage[Stats.DamageType.PHYSICAL] = base_damage
		stats.base_armor = base_armor
		stats.base_evasion = base_evasion
		stats.base_max_energy_shield = base_max_energy_shield
		stats.base_energy_shield_regen = base_energy_shield_regen
		stats.base_energy_shield_recharge_delay = base_energy_shield_recharge_delay
		max_health = float(stats.get_max_health())
		current_health = max_health
		max_energy_shield = stats.get_max_energy_shield()
		energy_shield = max_energy_shield
		buff_manager = BuffManager.new()
		buff_manager.stats = stats
		add_child(buff_manager)
		_player = get_tree().get_root().find_child("Player", true, false)
		_mesh = get_node_or_null("MeshInstance3D")
		if _mesh:
				_original_material = _mesh.material_override
		if healthbar_node_path != NodePath():
			_healthbar = get_node(healthbar_node_path)
			if(_healthbar):
				_healthbar.set_health(current_health, max_health)

func _physics_process(delta: float) -> void:
				_process_regen(delta)
				_process_timers(delta)
				var player_pos := _get_player_position()
				if player_pos and global_transform.origin.distance_to(player_pos) <= attack_range and _attack_timer <= 0.0 and main_skill:
						_attack_timer = main_skill.cooldown
						main_skill.perform(self)
				elif player_pos and global_transform.origin.distance_to(player_pos) <= detection_range:
						_chase(player_pos, delta)
				else:
						_wander(delta)

func _process_timers(delta: float) -> void:
				if _attack_timer > 0.0:
								_attack_timer -= delta

func _process_regen(delta: float) -> void:
		max_energy_shield = stats.get_max_energy_shield()
		if energy_shield < max_energy_shield:
				if _es_recharge_timer > 0.0:
						_es_recharge_timer -= delta
				else:
						energy_shield = min(max_energy_shield, energy_shield + stats.get_energy_shield_regen() * delta)

func _wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = wander_change_interval
		_current_dir = Vector3(randf() * 2.0 - 1.0, 0, randf() * 2.0 - 1.0).normalized()
	if _current_dir != Vector3.ZERO:
		var target_rot := Transform3D().looking_at(_current_dir, Vector3.UP).basis.get_euler().y
		rotation.y = lerp_angle(rotation.y, target_rot, 5.0 * delta)
	velocity = _current_dir * wander_speed
	move_and_slide()

func _chase(player_pos: Vector3, delta: float) -> void:
	var dir := (player_pos - global_transform.origin).normalized()
	var target_rot := Transform3D().looking_at(dir, Vector3.UP).basis.get_euler().y
	rotation.y = lerp_angle(rotation.y, target_rot, 5.0 * delta)
	velocity = dir * move_speed
	move_and_slide()


func _get_player_position() -> Vector3:
	if _player and _player.is_inside_tree():
		return _player.global_transform.origin
	return Vector3()

func add_buff(buff: Buff) -> void:
				if buff_manager:
								buff_manager.apply_buff(buff)

func remove_buff(buff: Buff) -> void:
				if buff_manager:
								buff_manager.remove_buff(buff)

func take_damage(amount: float, damage_type: Stats.DamageType = Stats.DamageType.PHYSICAL) -> void:
		print("AAA I AM TAKING ", amount, " ", damage_type, " DAMAGE")
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
		current_health -= amount
		if _healthbar:
				_healthbar.set_health(current_health, max_health)
		if current_health <= 0:
				die()

func die() -> void:
	_drop_loot()
	emit_signal("died")
	queue_free()

func _drop_loot() -> void:
	var drop_scene := preload("res://scenes/item_drop.tscn")
	for entry in drop_table:
		if randf() <= float(entry.get("chance", 1.0)):
			var drop := drop_scene.instantiate()
			var area := drop.get_node_or_null("Area3D")
			print(entry)
			if area and entry.has("item"):
				#print("that being said, entry item is ", entry["item"].item_name)
				area.item = entry["item"]
			if entry.has("amount"):
				area.amount = entry["amount"]
			print("dropping item ", area.item)
			
			get_parent().add_child(drop)
			drop.global_transform.origin = global_transform.origin
