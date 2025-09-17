extends Skill
class_name AreaBuffSkill

@export var radius: float = 3.0
@export var buff: Buff

func perform(user) -> void:
	if user == null or buff == null or not (user is Node3D):
		return
	var actor: Node3D = user
	var target := _get_ground_target_position(user)
	var mult := 1.0
	if "stats" in user and user.stats:
		mult = user.stats.get_aoe_multiplier()
	var shape := SphereShape3D.new()
	shape.radius = radius * mult
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), target)
	params.collide_with_bodies = true
	var world := actor.get_world_3d()
	if world == null:
		return
	var results := world.direct_space_state.intersect_shape(params, 128)
	var buff_template := _prepare_buff_instance(buff, user)
	for result in results:
		var body := result.get("collider")
		if body and body.has_method("add_buff") and buff_template:
			body.add_buff(buff_template.duplicate(true))
