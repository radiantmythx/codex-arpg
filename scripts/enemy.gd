extends CharacterBody3D

# =========================
# === Designer Exports ===
# =========================
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
@export var base_damage_types: Array[Stats.DamageType] = [Stats.DamageType.PHYSICAL]

@export var enemy_name: String = "Enemy"
@export var enemy_level: int = 1
@export var experience_given: int = 5

enum Tier { PACK, LEADER, BOSS }
@export var tier: Tier = Tier.PACK

const TIER_HEALTH_MULT := {Tier.PACK: 1.0, Tier.LEADER: 1.5, Tier.BOSS: 3.0}
const TIER_DAMAGE_MULT := {Tier.PACK: 1.0, Tier.LEADER: 1.25, Tier.BOSS: 2.0}
const TIER_SIZE_MULT   := {Tier.PACK: 1.0, Tier.LEADER: 1.25, Tier.BOSS: 1.75}
const OffscreenCuller  = preload("res://scripts/offscreen_culler.gd")
const HOVER_OUTLINE_SHADER := preload("res://resources/enemy_hover_outline.gdshader")

## Drop table: array of dicts like {"item": Item, "chance": 0.5, "amount": 1}
@export var drop_table: Array = []
@export var drop_tables: Array[DropTable] = []

# =========================
# === Runtime State     ===
# =========================
var current_health: float
var energy_shield: float = 0.0
var max_energy_shield: float = 0.0
var _es_recharge_timer: float = 0.0

signal died
var is_dead := false

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

# AnimationTree path cache (Suggestion #4)
const P_MOVE := &"parameters/move/blend_position"

# UI throttling (Suggestion #5)
var _ui_visible_until_ms := 0

# =========================
# === AI / LOD control  ===
# =========================
# Suggestion #2: Quantized/staggered AI updates
@export var ai_hz := 10.0      # AI runs at 10 Hz
var _ai_accum := 0.0
var _ai_quantum := 0.0         # 1 / ai_hz
var _ai_phase := 0.0           # per-instance stagger (seconds)

# Suggestion #3: LOD rings
enum LOD { ACTIVE, IDLE, SLEEP }
var _lod_state: int = LOD.ACTIVE

# =========================
# === Misc Display      ===
# =========================
var _original_modulate: Color = Color.WHITE

func _ready() -> void:
	randomize()
	add_to_group("enemy")

	# Motion mode trim (Suggestion #6)
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	floor_snap_length = 0.0

	# Stats setup
	stats = Stats.new()
	stats.base_max_health = max_health * TIER_HEALTH_MULT[tier]
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
		var surf_mat := _mesh.get_active_material(0)
		if surf_mat and surf_mat is BaseMaterial3D:
			_original_modulate = (surf_mat as BaseMaterial3D).albedo_color
		_mesh.scale = Vector3.ONE * TIER_SIZE_MULT[tier]

	_hover_outline_material = ShaderMaterial.new()
	_hover_outline_material.shader = HOVER_OUTLINE_SHADER

	if healthbar_node_path != NodePath():
		_healthbar = get_node(healthbar_node_path)
		if _healthbar:
			_healthbar.set_health(current_health, max_health)
			_healthbar.visible = false  # hidden unless hovered/damaged (Suggestion #5)
			if tier == Tier.BOSS:
				$Sprite3D.position.y *= 3.0

	# Offscreen culler (already present in your script)
	var _culler := OffscreenCuller.new()
	if _mesh:
		_culler.visual_path = _mesh.get_path()
	add_child(_culler)

	# AI quantization init (Suggestion #2)
	_ai_quantum = 1.0 / max(ai_hz, 0.001)
	_ai_phase = float(get_instance_id() & 255) / 255.0 * _ai_quantum

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# === Cheap regen tick (still every frame) ===
	_process_regen(delta)

	# === Quantized / staggered AI tick (Suggestion #2) ===
	_ai_accum += delta
	
	var do_ai = false
	while _ai_accum >= _ai_quantum:
		_ai_accum -= _ai_quantum
		# Stagger: only tick on frames past our phase
		if _ai_accum <= _ai_phase:
			do_ai = true

	# Cache transforms once per frame (Suggestion #1)
	var self_pos = global_position
	var player_pos = _get_player_position()  # returns Vector3.ZERO when missing
	var have_player = player_pos != Vector3.ZERO

	if do_ai and have_player:
		# LOD update (Suggestion #3)
		_apply_lod(player_pos)

		# Perception with squared distances + hysteresis (Suggestion #1)
		var d2 := self_pos.distance_squared_to(player_pos)
		var detect2 := detection_range * detection_range
		var lose2   := pow(detection_range * 5.0, 2.0)

		if _player_detected:
			_player_detected = d2 <= lose2
		else:
			_player_detected = d2 <= detect2

		# Attacks at AI rate
		_process_attack(_ai_quantum, player_pos)

		# Healthbar auto-hide throttled via AI tick (Suggestion #5)
		_late_ui_update()

	# Movement every frame, using decisions from last AI tick
	if _lod_state == LOD.SLEEP:
		velocity = Vector3.ZERO
	else:
		if _player_detected and have_player:
			_chase_cached(player_pos, self_pos, delta)
		else:
			_wander(delta)

	# Animation update (Suggestion #4)
	_update_animation()

# =========================
# === Core Behaviors    ===
# =========================
func _process_attack(dt: float, player_pos: Vector3) -> void:
	if _lod_state != LOD.ACTIVE:
		return

	if _attack_timer > 0.0:
		_attack_timer -= dt
	if _attacking_timer > 0.0:
		_attacking_timer -= dt
		_attack_progress += dt

		if not _attack_performed and _attack_progress >= _attack_execute_time:
			if main_skill:
				main_skill.perform(self)
			_attack_performed = true

		if _attack_cancel_time > 0.0 and _attack_progress >= _attack_cancel_time:
			_attacking_timer = 0.0

		if _attacking_timer <= 0.0 and _anim_state:
			_anim_state.travel("move")
	elif player_pos != Vector3.ZERO \
		and global_position.distance_squared_to(player_pos) <= attack_range * attack_range \
		and _attack_timer <= 0.0 and main_skill:
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
		_wander_timer = (randf() + 1.0) * wander_change_interval
		if randf() < 0.9:
			_current_dir = Vector3(randf() * 2.0 - 1.0, 0, randf() * 2.0 - 1.0).normalized()
		else:
			_current_dir = Vector3.ZERO

	if _current_dir != Vector3.ZERO:
		var target_rot := Basis().looking_at(_current_dir, Vector3.UP).get_euler().y
		rotation.y = lerp_angle(rotation.y, target_rot, 5.0 * delta)

	if _attacking_timer > 0.0:
		velocity = Vector3.ZERO
	else:
		velocity =  (_current_dir * wander_speed) if (_current_dir != Vector3.ZERO) else Vector3.ZERO

	# Movement trim (Suggestion #6)
	if velocity != Vector3.ZERO:
		move_and_slide()

func _chase_cached(player_pos: Vector3, self_pos: Vector3, delta: float) -> void:
	var dir := (player_pos - self_pos).normalized()
	var target_rot := Basis().looking_at(dir, Vector3.UP).get_euler().y
	rotation.y = lerp_angle(rotation.y, target_rot, 5.0 * delta)

	if _attacking_timer > 0.0:
		velocity = Vector3.ZERO
	else:
		velocity = dir * move_speed

	# Movement trim (Suggestion #6)
	if velocity != Vector3.ZERO:
		move_and_slide()

func _update_animation() -> void:
	if not _anim_tree or not _anim_state:
		return
	if _lod_state != LOD.ACTIVE:
		return
	if _attacking_timer > 0.0:
		return

	_anim_state.travel("move")

	# Cheap local velocity projection (Suggestion #4)
	var world_vel := Vector3(velocity.x, 0.0, velocity.z)
	var basis := global_transform.basis.orthonormalized()
	var local_x := world_vel.dot(basis.x)
	var local_y := world_vel.dot(-basis.z)
	_anim_tree.set(P_MOVE, Vector2(local_x, local_y))

# =========================
# === LOD Management    ===
# =========================
func _apply_lod(player_pos: Vector3) -> void:
	var d2 := global_position.distance_squared_to(player_pos)
	var r_active2 := pow(detection_range * 1.5, 2.0)
	var r_idle2   := pow(detection_range * 5.0, 2.0)

	if d2 <= r_active2:
		_set_active()
	elif d2 <= r_idle2:
		_set_idle()
	else:
		_set_sleep()

func _set_active() -> void:
	if _lod_state == LOD.ACTIVE:
		return
	_lod_state = LOD.ACTIVE
	visible = true
	set_physics_process(true)
	set_process(false) # we don't use _process here
	collision_layer = collision_layer | 1
	collision_mask  = collision_mask  | 1
	if _anim_tree:
		_anim_tree.active = true

func _set_idle() -> void:
	if _lod_state == LOD.IDLE:
		return
	_lod_state = LOD.IDLE
	visible = true
	set_physics_process(true)
	set_process(false)
	# No attacks while idle via _process_attack gate
	if _anim_tree:
		_anim_tree.active = false  # big perf win

func _set_sleep() -> void:
	if _lod_state == LOD.SLEEP:
		return
	_lod_state = LOD.SLEEP
	visible = false
	set_physics_process(true) # still needed for culling re-entry, movement is zeroed
	set_process(false)
	collision_layer = 0
	collision_mask  = 0
	if _anim_tree:
		_anim_tree.active = false

# =========================
# === UI / Hover        ===
# =========================
func set_hovered(hovered: bool) -> void:
	if not _mesh:
		return
	_mesh.material_overlay = _hover_outline_material if hovered else null
	# Keep bar visible briefly on hover (Suggestion #5)
	if _healthbar:
		if hovered:
			_healthbar.visible = true
			_ui_visible_until_ms = Time.get_ticks_msec() + 250
		else:
			# Let _late_ui_update() decide when to hide
			pass

func _late_ui_update() -> void:
	if _healthbar and tier != Tier.BOSS:
		if Time.get_ticks_msec() > _ui_visible_until_ms:
			_healthbar.visible = false

func _get_player_position() -> Vector3:
	if _player:
		return _player.global_position
	return Vector3.ZERO

# =========================
# === Combat & Damage   ===
# =========================
func add_buff(buff: Buff) -> void:
	if buff_manager:
		buff_manager.apply_buff(buff)

func remove_buff(buff: Buff) -> void:
	if buff_manager:
		buff_manager.remove_buff(buff)

func get_base_damage_dict(_tags := []) -> Dictionary:
	var dict: Dictionary = {}
	var mult = TIER_DAMAGE_MULT.get(tier, 1.0)
	for dt in base_damage_types:
		dict[dt] = Vector2(base_damage_low * mult, base_damage_high * mult)
	return dict

func _start_attack(skill: Skill) -> void:
	if _lod_state != LOD.ACTIVE:
		return
	var speed := stats.get_attack_speed_tagged(skill.tags) if stats else 1.0
	var scaled_speed = max(speed, 0.001)
	_attack_timer = skill.cooldown / scaled_speed
	_attacking_timer = skill.duration / scaled_speed
	_attack_progress = 0.0
	_attack_execute_time = skill.attack_time / scaled_speed
	_attack_cancel_time = skill.cancel_time / scaled_speed
	_attack_performed = false

	if _anim_state and skill.animation_name != &"":
		_anim_tree.set(("parameters/%s/TimeScale/scale" % str(skill.animation_name)), speed)
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
	amount *= (1.0 - resist / 100.0)
	amount *= (1.0 - stats.get_damage_reduction() / 100.0)
	amount = max(0.0, amount - stats.get_defense())
	if damage_type != Stats.DamageType.HOLY and damage_type != Stats.DamageType.UNHOLY and energy_shield > 0.0:
		var absorbed = min(energy_shield, amount)
		energy_shield -= absorbed
		amount -= absorbed
	_es_recharge_timer = stats.get_energy_shield_recharge_delay()
	current_health -= amount

	if _healthbar:
		_healthbar.set_health(current_health, max_health)
		_healthbar.visible = true
		_ui_visible_until_ms = Time.get_ticks_msec() + 2000  # show for 2s after damage

	if current_health <= 0.0 and not is_dead:
		die()

# =========================
# === Death / Loot      ===
# =========================
func die() -> void:
	if is_dead:
		return
	is_dead = true

	velocity = Vector3.ZERO
	set_physics_process(false)
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	set_process_unhandled_key_input(false)

	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	remove_from_group("enemy")

	current_health = 0.0
	if _healthbar:
		_healthbar.set_health(current_health, max_health)
		_healthbar.visible = false

	var chosen_state := _travel_to_random_death_animation()
	_drop_loot()
	emit_signal("died")

	if _player and _player.has_method("add_experience"):
		_player.add_experience(experience_given, enemy_level)

	if chosen_state != StringName():
		await get_tree().process_frame

	await get_tree().create_timer(5.0).timeout
	await _fade_out_and_queue_free()

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

func _fade_out_and_queue_free() -> void:
	if _mesh and _mesh is MeshInstance3D:
		var mat: Material = null
		if _mesh.material_override:
			mat = _mesh.material_override.duplicate()
		elif _mesh.mesh and _mesh.mesh.get_surface_count() > 0:
			var surf_mat := _mesh.mesh.surface_get_material(0)
			if surf_mat:
				mat = surf_mat.duplicate()
		if mat == null:
			mat = StandardMaterial3D.new()
		_mesh.material_override = mat

		if mat is BaseMaterial3D:
			var bmat := mat as BaseMaterial3D
			bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var t := create_tween()
			t.tween_property(bmat, "albedo_color:a", 0.0, 1.0)
			await t.finished
		elif mat is ShaderMaterial:
			var sm := mat as ShaderMaterial
			var uniform_names := ["tint", "albedo", "color", "albedo_color"]
			var found_name := ""
			for name in uniform_names:
				if sm.get_shader_parameter(name) is Color:
					found_name = name
					break
			if found_name != "":
				var start_col: Color = sm.get_shader_parameter(found_name)
				var t2 := create_tween()
				t2.tween_method(
					func(a: float) -> void:
						var c = sm.get_shader_parameter(found_name)
						c.a = a
						sm.set_shader_parameter(found_name, c),
					start_col.a, 0.0, 1.0
				)
				await t2.finished
	queue_free()

func _drop_loot() -> void:
	var drop_scene := preload("res://scenes/items/item_drop.tscn")
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
				if it and it.max_stack <= 1:
					area.item = it.duplicate(true)
				else:
					area.item = it
			if area and entry.has("amount"):
				area.amount = entry["amount"]
			get_parent().add_child(drop)
			drop.global_position = global_position
