extends CharacterBody3D

@export var max_health: float = 3.0
@export var move_speed: float = 2.0
@export var wander_speed: float = 1.0
@export var wander_change_interval: float = 2.0
@export var detection_range: float = 8.0
@export var attack_range: float = 1.5
@export var main_skill: Skill = preload("res://resources/skills/debug/fireball.tres")
@export var healthbar_node_path: NodePath
@export var animation_tree_path: NodePath
@export var death_animation_states: Array[StringName] = [] ## Optional state names in the AnimationTree to choose from on death.
@export var mesh: MeshInstance3D
@export var base_armor: float = 0.0
@export var base_evasion: float = 5.0 ## % chance to avoid incoming damage.
@export var base_block: float = 5.0 ## % chance to block after evasion.
@export var base_max_evasion: float = 75.0 ## Default evasion cap.
@export var base_max_block: float = 75.0 ## Default block cap.
@export var base_damage_reduction: float = 10.0 ## % reduction applied after resistances.
@export var base_max_energy_shield: float = 0.0
@export var base_energy_shield_regen: float = 0.0
@export var base_energy_shield_recharge_delay: float = 2.0
@export var base_damage_low: float = 1.0
@export var base_damage_high: float = 2.0
@export var base_attack_speed: float = 1.0
# Enemies can deal multiple damage types. All listed types use the same damage
# range defined above. Designers can duplicate an enemy and tweak the lists to
# create variants like fire or ice versions.
@export var base_damage_types: Array[Stats.DamageType] = [Stats.DamageType.PHYSICAL]

# Display properties used by the hover UI.  The health bar overlay will read
# these so the enemy's name and level can be shown to the player.
@export var enemy_name: String = "Enemy"
@export var enemy_level: int = 1

# Enemy tier determines how tough the monster is. Higher tiers get scaled stats
# and damage and are intended for special encounters.
enum Tier { PACK, LEADER, BOSS }
@export var tier: Tier = Tier.PACK

const TIER_HEALTH_MULT := {Tier.PACK: 1.0, Tier.LEADER: 1.5, Tier.BOSS: 3.0}
const TIER_DAMAGE_MULT := {Tier.PACK: 1.0, Tier.LEADER: 1.25, Tier.BOSS: 2.0}
const TIER_SIZE_MULT := {Tier.PACK: 1.0, Tier.LEADER: 1.25, Tier.BOSS: 1.75}
const OffscreenCuller = preload("res://scripts/offscreen_culler.gd")

## Drop table is an array of dictionaries like:
## {"item": Item, "chance": 0.5, "amount": 1}
@export var drop_table: Array = []

# Optional list of reusable DropTable resources. All entries from these tables
# are merged with `drop_table` when generating loot.
@export var drop_tables: Array[DropTable] = []

var current_health: float
var energy_shield: float = 0.0
var max_energy_shield: float = 0.0
var _es_recharge_timer: float = 0.0

signal died
var is_dead:bool = false

var _player: Node3D
var _wander_timer: float = 0.0
var _current_dir: Vector3 = Vector3.ZERO
var _attack_timer: float = 0.0
var _attacking_timer: float = 0.0
var _attack_progress: float = 0.0
var _attack_execute_time: float = 0.0
var _attack_cancel_time: float = 0.0
var _attack_performed: bool = false
var _mesh: MeshInstance3D
var _original_material: Material
var _hover_outline_material: ShaderMaterial
var _healthbar: Healthbar
var stats: Stats
var buff_manager: BuffManager
var _anim_tree: AnimationTree
var _anim_state: AnimationNodeStateMachinePlayback
var _player_detected: bool = false
var _original_modulate: Color = Color.WHITE ## Stored so the fade-out tween preserves the original tint when rebuilding.

const HOVER_OUTLINE_SHADER := preload("res://resources/enemy_hover_outline.gdshader")

func _ready() -> void:
	randomize()
	add_to_group("enemy")
	stats = Stats.new()
		# Scale core stats based on tier so bosses feel tougher.
	stats.base_max_health = max_health * TIER_HEALTH_MULT[tier]
		# Enemies don't rely on Stats.base_damage; damage is rolled from
		# `get_base_damage_dict` instead, so set all base damages to zero.
	for dt in Stats.DAMAGE_TYPES:
		stats.base_damage[dt] = 0.0
		stats.base_armor = base_armor
		stats.base_evasion = base_evasion
		stats.base_block = base_block
		stats.base_max_evasion = base_max_evasion
		stats.base_max_block = base_max_block
		stats.base_damage_reduction = base_damage_reduction
		stats.base_max_energy_shield = base_max_energy_shield
		stats.base_energy_shield_regen = base_energy_shield_regen
		stats.base_energy_shield_recharge_delay = base_energy_shield_recharge_delay
	stats.base_attack_speed = base_attack_speed
	max_health = float(stats.get_max_health())
	current_health = max_health
	max_energy_shield = stats.get_max_energy_shield()
	energy_shield = max_energy_shield
	buff_manager = BuffManager.new()
	buff_manager.stats = stats
	add_child(buff_manager)
	_player = get_tree().get_root().find_child("Player", true, false)
	if animation_tree_path != NodePath():
						_anim_tree = get_node_or_null(animation_tree_path)
						if _anim_tree:
										_anim_tree.active = true
										_anim_state = _anim_tree.get("parameters/playback")
	_mesh = mesh
	if _mesh:
			_original_material = _mesh.material_override
			_original_modulate = _mesh.get_active_material(0).albedo_color
			_mesh.scale = Vector3(TIER_SIZE_MULT[tier], TIER_SIZE_MULT[tier], TIER_SIZE_MULT[tier])
						# Create a material using the hover outline shader.  It will be
			# assigned to `material_overlay` when the mouse hovers this enemy
			# so the original surface materials remain visible.
	_hover_outline_material = ShaderMaterial.new()
	_hover_outline_material.shader = HOVER_OUTLINE_SHADER
	if healthbar_node_path != NodePath():
					_healthbar = get_node(healthbar_node_path)
					if(_healthbar):
							_healthbar.set_health(current_health, max_health)
							if(tier == Tier.BOSS):
									$Sprite3D.position.y *= 3

	# Instantiate a culler so enemies outside the camera view are paused
	# and hidden, allowing thousands of enemies without impacting the editor.
	var _culler := OffscreenCuller.new()
	if _mesh:
			_culler.visual_path = _mesh.get_path()
	add_child(_culler)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_process_regen(delta)
	var player_pos := _get_player_position()
	_process_attack(delta, player_pos)
	if player_pos:
					var dist := global_transform.origin.distance_to(player_pos)
					if _player_detected:
									if dist > detection_range * 5.0:
													_player_detected = false
					elif dist <= detection_range:
									_player_detected = true
	if _player_detected and player_pos:
					_chase(player_pos, delta)
	else:
					_wander(delta)
	_update_animation()

func _process_attack(delta: float, player_pos: Vector3) -> void:
		if _attack_timer > 0.0:
				_attack_timer -= delta
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
		elif player_pos and global_transform.origin.distance_to(player_pos) <= attack_range and _attack_timer <= 0.0 and main_skill:
						_start_attack(main_skill)

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
				_wander_timer = (randf() + 1) * wander_change_interval
				if(randf() < 0.9):
					_current_dir = Vector3(randf() * 2.0 - 1.0, 0, randf() * 2.0 - 1.0).normalized()
				else:
					_current_dir = Vector3.ZERO
		if _current_dir != Vector3.ZERO:
				var target_rot := Transform3D().looking_at(_current_dir, Vector3.UP).basis.get_euler().y
				rotation.y = lerp_angle(rotation.y, target_rot, 5.0 * delta)
		if _attacking_timer > 0.0:
				velocity = Vector3.ZERO
		else:
				if(_current_dir != Vector3.ZERO):
					velocity = _current_dir * wander_speed
				else:
					velocity = Vector3.ZERO
		move_and_slide()

func _chase(player_pos: Vector3, delta: float) -> void:
				var dir := (player_pos - global_transform.origin).normalized()
				var target_rot := Transform3D().looking_at(dir, Vector3.UP).basis.get_euler().y
				rotation.y = lerp_angle(rotation.y, target_rot, 5.0 * delta)
				if _attacking_timer > 0.0:
						velocity = Vector3.ZERO
				else:
						velocity = dir * move_speed
				move_and_slide()

func _update_animation() -> void:
		if not _anim_tree or not _anim_state:
				return
		if _attacking_timer > 0.0:
				return
		_anim_state.travel("move")
		var world_vel = Vector3(velocity.x, 0, velocity.z)
		var basis = global_transform.basis.orthonormalized()
		var right = basis.x
		var forward = -basis.z
		var local_x = world_vel.dot(right)
		var local_y = world_vel.dot(forward)
		_anim_tree.set("parameters/move/blend_position", Vector2(local_x, local_y))

func set_hovered(hovered: bool) -> void:
		# Toggles the thin red outline when the mouse is over the enemy.
		# We use `material_overlay` so the original material is still rendered.
		#print(hovered)
		if not _mesh:
				return
		_mesh.material_overlay = _hover_outline_material if hovered else null


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

# Returns the enemy's innate base damage ranges as a dictionary keyed by
# DamageType.  Skill scripts call this so the values are merged with the
# skill's own base damage when attacks are performed.
func get_base_damage_dict(_tags := []) -> Dictionary:
				var dict: Dictionary = {}
				var mult = TIER_DAMAGE_MULT.get(tier, 1.0)
				for dt in base_damage_types:
								dict[dt] = Vector2(base_damage_low * mult, base_damage_high * mult)
				return dict

func _start_attack(skill: Skill) -> void:
				var speed := stats.get_attack_speed_tagged(skill.tags) if stats else 1.0
				var scaled_speed = max(speed, 0.001)
				_attack_timer = skill.cooldown / scaled_speed
				_attacking_timer = skill.duration / scaled_speed
				_attack_progress = 0.0
				_attack_execute_time = skill.attack_time / scaled_speed
				_attack_cancel_time = skill.cancel_time / scaled_speed
				_attack_performed = false
				print(_anim_state)
				print(skill.animation_name)
				if _anim_state and skill.animation_name != &"":
								print("SETTING TIMESCALE TO ", speed)
								_anim_tree.set("parameters/%s/TimeScale/scale" % str(skill.animation_name), speed)
								_anim_state.travel(String(skill.animation_name), true)
				else:
								skill.perform(self)
								_attack_performed = true
								_attacking_timer = 0.0

func take_damage(amount: float, damage_type: Stats.DamageType = Stats.DamageType.PHYSICAL) -> void:
	if is_dead:
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
	current_health -= amount
	if _healthbar:
		_healthbar.set_health(current_health, max_health)
	if current_health <= 0 and not is_dead:
			die()

func die() -> void:
	if is_dead:
			return

	is_dead = true

	# Stop all locomotion and combat logic immediately so the enemy no
	# longer chases or attacks while the death sequence plays.
	velocity = Vector3.ZERO
	set_physics_process(false)
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	set_process_unhandled_key_input(false)

	# Remove collision interactions so the corpse cannot be hit by further
	# attacks or interfere with navigation.  The group removal ensures hover
	# UI stops targeting the dead enemy instantly.
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	remove_from_group("enemy")

	# Guarantee health values hit zero so connected UI reflects the change
	# even before loot is collected.
	current_health = 0.0
	if _healthbar:
		_healthbar.set_health(current_health, max_health)
		_healthbar.visible = false

	var chosen_state := _travel_to_random_death_animation()

	_drop_loot()
	emit_signal("died")

	# Allow the animation to begin before the linger timer starts.  When no
	# animation data is available we still fall through instantly.
	if chosen_state != StringName():
			await get_tree().process_frame

	await get_tree().create_timer(5.0).timeout
	await _fade_out_and_queue_free()

## Selects a random AnimationTree state from the exported list and travels to it.
## Returns the state that was used so callers can optionally react to its length.
func _travel_to_random_death_animation() -> StringName:
		if not _anim_state:
				return StringName()

		var valid_states: Array[StringName] = []
		for state_name in death_animation_states:
				if String(state_name) != "":
						valid_states.append(state_name)

		if valid_states.is_empty():
				return StringName()

		var chosen_state: StringName = valid_states.pick_random()
		_anim_state.travel(chosen_state)
		return chosen_state

## Fades the mesh out smoothly over one second before freeing the node.  A tween
## is used so the fade keeps running even though normal processing has been
## disabled for the enemy.
func _fade_out_and_queue_free() -> void:
	if _mesh and _mesh is MeshInstance3D:
		var mat: Material = null

		# Prefer a unique override material so we don't affect shared resources.
		if _mesh.material_override:
			mat = _mesh.material_override.duplicate()
		elif _mesh.mesh and _mesh.mesh.get_surface_count() > 0:
			var surf_mat := _mesh.mesh.surface_get_material(0)
			if surf_mat:
				mat = surf_mat.duplicate()

		# Fall back to a fresh StandardMaterial3D if nothing found.
		if mat == null:
			mat = StandardMaterial3D.new()

		# Install the unique material as the override.
		_mesh.material_override = mat

		# Handle BaseMaterial3D (Standard/ORM) vs ShaderMaterial.
		if mat is BaseMaterial3D:
			var bmat := mat as BaseMaterial3D
			# Ensure alpha blending is on so changes to .a actually render.
			bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			# Optional: keep depth write for nicer fade on top of itself
			# bmat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALPHA_PREPASS

			var tween := create_tween()
			# Tween the material resource's color alpha directly.
			tween.tween_property(bmat, "albedo_color:a", 0.0, 1.0)
			await tween.finished

		elif mat is ShaderMaterial:
			var sm := mat as ShaderMaterial
			# Expect a Color uniform to drive opacity; try a few common names.
			var uniform_names := ["tint", "albedo", "color", "albedo_color"]
			var found_name := ""
			for name in uniform_names:
				if sm.get_shader_parameter(name) is Color:
					found_name = name
					break

			if found_name != "":
				var start_col: Color = sm.get_shader_parameter(found_name)
				var tween := create_tween()
				# Tween via a setter function to only change alpha.
				tween.tween_method(
					func(a: float) -> void:
						var c = sm.get_shader_parameter(found_name)
						c.a = a
						sm.set_shader_parameter(found_name, c),
					start_col.a, 0.0, 1.0
				)
				await tween.finished
			else:
				# As a fallback, just free without fade.
				push_warning("No Color uniform found to fade; freeing without fade.")
	else:
		# No mesh available; just free.
		pass

	queue_free()

func _drop_loot() -> void:
		var drop_scene := preload("res://scenes/item_drop.tscn")
		var combined: Array = []
		combined.append_array(drop_table)
		for table in drop_tables:
				if table:
						combined.append_array(table.entries)
		for entry in combined:
				if randf() <= float(entry.get("chance", 1.0)):
						var drop := drop_scene.instantiate()
						var area := drop.get_node_or_null("Area3D")
						if area and entry.has("item"):
										var it: Item = entry["item"]
										# Duplicate non-stackable items so affix crafting on one drop
										# doesn't modify other instances.
										if it and it.max_stack <= 1:
												area.item = it.duplicate(true)
										else:
												area.item = it
						if area and entry.has("amount"):
								area.amount = entry["amount"]
						get_parent().add_child(drop)
						drop.global_transform.origin = global_transform.origin
