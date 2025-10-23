extends Node

var player_container:PlayerContainer
var player:PlayerCharacter
var player_cam:Camera3D
var player_springArm:PlayerSpringArmCamera

func _initialize_player(pc:PlayerContainer):
	player_container = pc
	player = pc.get_player()
	player_springArm = pc.get_player_springarm()
	player_cam = pc.get_player_cam()
	
func freeze_player(setting: bool):
	player.set_frozen_and_ignore(setting)
	
func freeze_player_springarm(setting: bool):
	player_springArm.set_is_locked(setting)

#Used in character creation to force character to be a certain rotation
func set_visual_player_rotation_override(degrees: float):
	player.rotation.y = deg_to_rad(degrees)
	
func set_visual_player_scale_override(new_scale: Vector3):
	player.scale = new_scale
	
func update_player_race(race:String, added_race_visuals:Array[PackedScene]):
	reset_player_race_visuals()
	for c in added_race_visuals:
		add_player_race_visual(c)
		await get_tree().process_frame
	await get_tree().process_frame
	player_container.set_player_race(race)
	match race:
		"Human":
			set_visual_player_scale_override(Vector3(1, 1, 1))
			set_player_texture_color_override("skin_color", Color("#e7c6a3"))
			force_player_oneshot_and_idle("CastSpellSmite")
		"Elf":
			set_visual_player_scale_override(Vector3(0.9, 1.1, 0.9))
			set_player_texture_color_override("skin_color", Color("#fdd3a9"))
			force_player_oneshot_and_idle("BowAttack")
			#set_player_texture_color_override("skin_color", Color("#6d721b"))
		"Gnome":
			set_visual_player_scale_override(Vector3(0.65, 0.65, 0.65))
			set_player_texture_color_override("skin_color", Color("#fabab2"))
			force_player_oneshot_and_idle("Leap")
		"Lich":
			set_visual_player_scale_override(Vector3(0.65, 0.95, 0.65))
			set_player_texture_color_override("skin_color", Color("#afd3e0"))
			force_player_oneshot_and_return("CastSpellAura")
		"Orc":
			set_visual_player_scale_override(Vector3(1.1, 1.1, 1.1))
			set_player_texture_color_override("skin_color", Color("#6d721b"))
			force_player_oneshot_and_idle("strike")
		"Dwarf":
			set_visual_player_scale_override(Vector3(1.1, 0.85, 1.1))
			set_player_texture_color_override("skin_color", Color("#736b5f"))
			force_player_oneshot_and_idle("roll")
		"Goblin":
			set_visual_player_scale_override(Vector3(1, 0.8, 1))
			set_player_texture_color_override("skin_color", Color("#227400"))
			force_player_oneshot_and_idle("Death")
		_:
			print("Switched race to ", race)
	
			
func reset_player_race_visuals():
	player_container.reset_player_race_visuals()
			
func add_player_race_visual(scene:PackedScene):
	player_container.add_player_race_visual(scene)
	
func set_player_texture_color_override(surface_name: String, color: Color):
	player_container.set_surface_albedo(surface_name, color)
	
func force_player_oneshot_and_return(animStateName:String):
	player_container.force_player_oneshot_and_return(animStateName)
	
func force_player_oneshot_and_idle(animStateName):
	player_container.force_player_oneshot_and_idle(animStateName)

func set_player_blendshape(blendShape:String, amount:float):
	player_container.set_player_bodymesh_blendshape(blendShape, amount)
	
func set_player_hair(hairScene:PackedScene):
	player_container.set_player_hair(hairScene)

var player_set_skill_choice:Skill

func set_player_set_skill_choice(new_skill:Skill):
	player_set_skill_choice = new_skill
	print("Global player handler recognizes the new skill as ", new_skill.name)
	
func update_player_skill(new_skill, index):
	player_container.player.set_skill_slot(index, new_skill)
