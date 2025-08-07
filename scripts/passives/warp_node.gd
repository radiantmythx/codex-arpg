class_name WarpNode
extends PassiveNode

@export var warp_connections: Array[NodePath] = []

func get_connected_nodes() -> Array:
    var result: Array = super.get_connected_nodes()
    if allocated:
        for p in warp_connections:
            var n = get_node_or_null(p)
            if n and n.allocated:
                result.append(n)
    return result

func get_draw_connections() -> Array:
    var arr: Array = super.get_draw_connections()
    for p in warp_connections:
        var n = get_node_or_null(p)
        if n:
            arr.append({"target": n, "color": Color.CORNFLOWER_BLUE})
    return arr
