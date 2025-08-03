extends Skill
class_name AreaBuffSkill

@export var radius: float = 3.0
@export var buff: Buff

func perform(user):
    if user == null or buff == null:
        return
    var camera = user.get_viewport().get_camera_3d()
    if camera == null:
        return
    var mouse_pos = user.get_viewport().get_mouse_position()
    var ray_origin = camera.project_ray_origin(mouse_pos)
    var ray_dir = camera.project_ray_normal(mouse_pos)
    var plane_y = user.global_transform.origin.y
    if abs(ray_dir.y) <= 0.0001:
        return
    var distance = (plane_y - ray_origin.y) / ray_dir.y
    var target = ray_origin + ray_dir * distance
    var mult = user.stats.get_aoe_multiplier()
    var shape = SphereShape3D.new()
    shape.radius = radius * mult
    var params = PhysicsShapeQueryParameters3D.new()
    params.shape = shape
    params.transform = Transform3D(Basis(), target)
    params.collide_with_bodies = true
    var bodies = user.get_world_3d().direct_space_state.intersect_shape(params)
    for result in bodies:
        var body = result.get("collider")
        if body and body.has_method("add_buff"):
            body.add_buff(buff)
