extends Skill
class_name TranscendentFireSkill

@export var radius: float = 3.0
@export var damage_per_second: float = 1.0
@export var mana_drain: float = 1.0
@export var health_drain: float = 0.5

var _active: Dictionary = {}

class AuraArea extends Area3D:
		var skill: TranscendentFireSkill
		var user
		var shape: CylinderShape3D

		func _ready():
				monitoring = true
				var mult = user.stats.get_aoe_multiplier()
				shape = CylinderShape3D.new()
				shape.height = 1.0
				shape.radius = skill.radius * mult
				var collider = CollisionShape3D.new()
				collider.shape = shape
				add_child(collider)
				var mesh = MeshInstance3D.new()
				var cmesh = CylinderMesh.new()
				cmesh.top_radius = shape.radius
				cmesh.bottom_radius = shape.radius
				cmesh.height = 0.5
				mesh.mesh = cmesh
				var mat = StandardMaterial3D.new()
				mat.albedo_color = Color(1,0.5,0,0.3)
				mesh.material_override = mat
				add_child(mesh)
				set_physics_process(true)

		func _physics_process(delta):
				var dmg_map = user.stats.get_all_damage(skill.tags)
				for body in get_overlapping_bodies():
						if body and body.has_method("take_damage") and body.is_in_group("enemy"):
								for dt in dmg_map.keys():
										print(dt)
										var dmg = (dmg_map[dt]) * skill.damage_per_second
										print(dmg)
										if dmg > 0:
												body.take_damage(dmg * delta, dt)
				if "mana" in user:
						user.mana -= skill.mana_drain * delta
				if "health" in user:
						user.health -= skill.health_drain * delta
				if ("mana" in user and user.mana <= 0) or ("health" in user and user.health <= 0):
						skill._deactivate(user)

func _deactivate(user):
		if _active.has(user):
				var area = _active[user]
				if is_instance_valid(area):
						area.queue_free()
				_active.erase(user)

func perform(user):
		if user == null:
				return
		if _active.has(user):
				_deactivate(user)
		else:
				var area = AuraArea.new()
				area.skill = self
				area.user = user
				user.add_child(area)
				_active[user] = area
